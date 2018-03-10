#--
# Copyright 2011-2013 Splunk, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"): you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#++

##
# +resultsreader.rb+ provides classes to incrementally parse the XML output from
# Splunk search jobs. For most search jobs you will want +ResultsReader+, which
# handles a single results set. However, the running a blocking export job from
# the +search/jobs/export endpoint+ sends back a stream of results sets, all but
# the last of which are previews. In this case, you should use the
# +MultiResultsReader+, which will let you iterate over the results sets.
#
# By default, +ResultsReader+ will try to use Nokogiri for XML parsing. If
# Nokogiri isn't available, it will fall back to REXML, which ships with Ruby
# 1.9. See +xml_shim.rb+ for how to alter this behavior.
#

#--
# There are two basic designs we could have used for handling the
# search/jobs/export output. We could either have the user call
# +ResultsReader#each+ multiple times, each time going through the next results
# set, or we could do what we have here and have an outer iterator that yields
# distinct +ResultsReader+ objects for each results set.
#
# The outer iterator is syntactically somewhat clearer, but you must invalidate
# the previous +ResultsReader+ objects before yielding a new one so that code
# like
#
#     readers = []
#     outer_iter.each do |reader|
#         readers << reader
#     end
#     readers[2].each do |result|
#         puts result
#     end
#
# will throw an error on the second each. The right behavior is to throw an
# exception in the +ResultsReader+ each if it is invoked out of order. This
# problem doesn't affect the all-in-one design.
#
# However, in the all-in-one design, it is impossible to set the is_preview and
# fields instance variables of the +ResultsReader+ correctly between invocations
# of each. This makes code with the all-in-one design such as
#
#     while reader.is_preview
#         reader.each do |result|
#           ...
#         end
#     end
#
# If the ... contains a break, then there is no way to set is_preview correctly
# before the next iteration of the while loop. This problem does not affect
# the outer iterator design, and Fred Ross and Yunxin Wu were not able to come
# up with a way to make it work in the all-in-one design, so the SDK uses the
# outer iterator design.
#++

require 'stringio'

require_relative 'xml_shim'
require_relative 'collection/jobs' # To access ExportStream

module Splunk
  # +ResultsReader+ parses Splunk's XML format for results into Ruby objects.
  #
  # You can use both Nokogiri and REXML. By default, the +ResultsReader+ will
  # try to use Nokogiri, and if it is not available will fall back to REXML. If
  # you want other behavior, see +xml_shim.rb+ for how to set the XML library.
  #
  # +ResultsReader is an +Enumerable+, so it has methods such as +each+ and
  # +each_with_index+. However, since it's a stream parser, once you iterate
  # through it once, it will thereafter be empty.
  #
  # Do not use +ResultsReader+ with the results of the +create_export+ or
  # +create_stream+ methods on +Service+ or +Jobs+. These methods use endpoints
  # which return a different set of data structures. Use +MultiResultsReader+
  # instead for those cases. If you do use +ResultsReader+, it will return
  # a concatenation of all non-preview events in the stream, but that behavior
  # should be considered deprecated, and will result in a warning.
  #
  # The ResultsReader object has two additional methods:
  #
  # * +is_preview?+ returns a Boolean value that indicates whether these 
  #   results are a preview from an unfinished search or not
  # * +fields+ returns an array of all the fields that may appear in a result
  #   in this set, in the order they should be displayed (if you're going
  #   to make a table or the like)
  #
  # The values yielded by calling +each+ and similar methods on +ResultsReader+
  # are of class +Event+, which is a subclass of +Hash+ with one extra method,
  # +segmented_raw+. The fields of the event are available as values in the hash,
  # with no escaped characters and no XML tags. The +_raw+ field, however, is
  # returned with extra XML specifying how terms should be highlighted for
  # display, and this full XML form is available by called the +segmented_raw+
  # method. The XML returned looks something like:
  #
  #     "<v xml:space=\"preserve\" trunc=\"0\">127.0.0.1 - admin
  #     [11/Feb/2013:10:42:49.790 -0800] \"POST /services/search/jobs/export
  #     HTTP/1.1\" 200 440404 - - - 257ms</v>"
  #
  # *Example*:
  #
  #     require 'splunk-sdk-ruby'
  #
  #     service = Splunk::connect(:username => "admin", :password => "changeme")
  #
  #     stream = service.jobs.create_oneshot("search index=_internal | head 10")
  #     reader = Splunk::ResultsReader.new(stream)
  #     puts reader.is_preview?
  #     # Prints: false
  #     reader.each do |result|
  #       puts result # Prints the fields in the result as a Hash
  #       puts result.segmented_raw() # Prints the XML version of the _raw field
  #     end
  #     # Prints a sequence of Hashes containing events.
  #
  class ResultsReader
    include Enumerable

    ##
    # Are the results in this reader a preview from an unfinished search?
    #
    # Returns: +true+ or +false+, or +nil+ if the stream is empty.
    #
    def is_preview?
      return @is_preview
    end

    ##
    # An +Array+ of all the fields that may appear in each result.
    #
    # Note that any given result will contain a subset of these fields.
    #
    # Returns: an +Array+ of +Strings+.
    #
    attr_reader :fields

    def initialize(text_or_stream)
      if text_or_stream.nil?
        stream = StringIO.new("")
      elsif text_or_stream.is_a?(ExportStream)
        # The sensible behavior on streams from the export endpoints is to
        # skip all preview results and concatenate all others. The export
        # functions wrap their streams in ExportStream to mark that they need
        # this special handling.
        @is_export = true
        @reader = MultiResultsReader.new(text_or_stream).final_results()
        @is_preview = @reader.is_preview?
        @fields = @reader.fields
        return
      elsif !text_or_stream.respond_to?(:read)
        # Strip because the XML libraries can be pissy.
        stream = StringIO.new(text_or_stream.strip)
      else
        stream = text_or_stream
      end

      if !stream.nil? and stream.eof?
        @is_preview = nil
        @fields = []
      else
        # We use a SAX parser. +listener+ is the event handler, but a SAX
        # parser won't usually transfer control during parsing. 
        # To incrementally return results as we parse, we have to put
        # the parser into a +Fiber+ from which we can yield.
        listener = ResultsListener.new()
        @iteration_fiber = Fiber.new do
          if $splunk_xml_library == :nokogiri
            parser = Nokogiri::XML::SAX::Parser.new(listener)
            parser.parse(stream)
          else # Use REXML
            REXML::Document.parse_stream(stream, listener)
          end
        end

        @is_preview = @iteration_fiber.resume
        @fields = @iteration_fiber.resume
        @reached_end = false
      end
    end

    def each()
      # If we have been passed a stream from an export endpoint, it should be
      # marked as such, and we handle it differently.
      if @is_export
        warn "[DEPRECATED] Do not use ResultsReader on the output of the " +
                 "export endpoint. Use MultiResultsReader instead."
        enum = @reader.each()
      else
        enum = Enumerator.new() do |yielder|
          if !@iteration_fiber.nil? # Handle the case of empty files
            @reached_end = false
            while true
              result = @iteration_fiber.resume
              break if result.nil? or result == :end_of_results_set
              yielder << result
            end
          end
          @reached_end = true
        end
      end

      if block_given? # Apply the enumerator to a block if we have one
        enum.each() { |e| yield e }
      else
        enum # Otherwise return the enumerator itself
      end
    end

    ##
    # Skips the rest of the events in this ResultsReader.
    #
    def skip_remaining_results()
      if !@reached_end
        each() { |result|}
      end
    end
  end

  ##
  # +Event+ represents a single event returned from a +ResultsReader+.
  #
  # +Event+ is a subclass of +Hash+, adding a single method +segmented_raw()+
  # which returns a string containing the XML of the raw event, as opposed
  # to the unescaped, raw strings returned by fetching a particular field
  # via [].
  #
  class Event < Hash
    @raw_xml = nil

    attr_writer :raw_xml

    def segmented_raw
      @raw_xml
    end
  end

  ##
  # +ResultsListener+ is the SAX event handler for +ResultsReader+.
  #
  # The authors of Nokogiri decided to make their SAX interface
  # slightly incompatible with that of REXML. For example, REXML
  # uses tag_start and passes attributes as a dictionary, while
  # Nokogiri calls the same thing start_element, and passes
  # attributes as an association list.
  #
  # This is a classic finite state machine parser. The `@states` variable
  # contains a hash with the states as its values. Each hash contains
  # functions giving the behavior of the state machine in that state.
  # The actual methods on the function dispatch to these functions
  # based upon the current state (as stored in `@state`).
  #
  # The parser initially runs until it has determined if the results are
  # a preview, then calls +Fiber.yield+ to return it. Then it continues and
  # tries to yield a field order, and then any results. (It will always yield
  # a field order, even if it is empty). At the end of a results set, it yields
  # +:end_of_results_set+.
  #
  class ResultsListener # :nodoc:
    def initialize()
      # @fields holds the accumulated list of fields from the fieldOrder
      # element. If there has been no accumulation, it is set to
      # :no_fieldOrder_found. For empty results sets, there is often no
      # fieldOrder element, but we still want to yield an empty Array at the
      # right point, so if we reach the end of a results element and @fields
      # is still :no_fieldOrder_found, we yield an empty array at that point.
      @fields = :no_fieldOrder_found
      @concatenate = false
      @is_preview = nil
      @state = :base
      @msg_type = nil
      @states = {
          # Toplevel state.
          :base => {
              :start_element => lambda do |name, attributes|
                if name == "response"
                  @state = :response
                elsif name == "results"
                  if !@concatenate
                    @is_preview = attributes["preview"] == "1"
                    Fiber.yield(@is_preview)
                  end
                elsif name == "fieldOrder"
                  if !@concatenate
                    @state = :field_order
                    @fields = []
                  end
                elsif name == "result"
                  @state = :result
                  @current_offset = Integer(attributes["offset"])
                  @current_result = Event.new()
                end
              end,
              :end_element => lambda do |name|
                if name == "results" and !@concatenate
                  Fiber.yield([]) if @fields == :no_fieldOrder_found

                  if !@is_preview # Start concatenating events
                    @concatenate = true
                  else
                    # Reset the fieldOrder
                    @fields = :no_fieldOrder_found
                    Fiber.yield(:end_of_results_set)
                  end
                end
              end
          },
          :response => {
              :start_element => lambda do |name, attributes|
                if name == 'messages'
                  @state = :response_messages
                end
              end,
          },
          :response_messages => {
              :start_element => lambda do |name, attributes|
                if name == "msg"
                  case attributes['type']
                  when 'ERROR', 'FATAL'
                    @state = :response_messages_msg
                    @msg_type = attributes['type']
                  end
                end
              end,
          },
          :response_messages_msg => {
            :characters => lambda do |text|
              raise "#{@msg_type}: #{text}"
            end,
          },
          # Inside a `fieldOrder` element. Recognizes only
          # the `field` element, and returns to the `:base` state
          # when it encounters `</fieldOrder>`.
          :field_order => {
              :start_element => lambda do |name, attributes|
                if name == "field"
                  @state = :field_order_field
                end
              end,
              :end_element => lambda do |name|
                if name == "fieldOrder"
                  @state = :base
                  Fiber.yield(@fields)
                end
              end
          },
          # When the parser in `:field_order` state encounters
          # a `field` element, it jumps to this state to record it.
          # When `</field>` is encountered, jumps back to `:field_order`.
          :field_order_field => {
              :characters => lambda do |text|
                @fields << text.strip
              end,
              :end_element => lambda do |name|
                if name == "field"
                  @state = :field_order
                end
              end
          },
          # When the parser has hit the `result` element, it jumps here.
          # When this state hits `</result>`, it calls `Fiber.yield` to
          # send the completed result back, and, when the fiber is
          # resumed, jumps back to the `:base` state.
          :result => {
              :start_element => lambda do |name, attributes|
                if name == "field"
                  @current_field = attributes["k"]
                  @current_value = nil
                elsif name == "text" || name == "v"
                  @state = :field_values
                  @current_text = ""
                  s = ["v"] + attributes.map do |entry|
                    key, value = entry
                    # Nokogiri and REXML both drop the namespaces of attributes,
                    # and there is no way to recover them. To reconstruct the
                    # XML (since we can't get at its raw form) we put in the
                    # one instance of a namespace on an attribute that shows up
                    # in what Splunk returns. Yes, this is a terribly, ugly
                    # kludge.
                    if key == "space"
                      prefixed_key = "xml:space"
                    else
                      prefixed_key = key
                    end
                    "#{prefixed_key}=\"#{value}\""
                  end
                  @current_xml = "<" + s.join(" ") + ">"
                end
              end,
              :end_element => lambda do |name|
                if name == "result"
                  Fiber.yield @current_result
                  @current_result = nil
                  @current_offset = nil
                  @state = :base
                elsif name == "field"
                  if @current_result.has_key?(@current_field)
                    if @current_result[@current_field].is_a?(Array)
                      @current_result[@current_field] << @current_value
                    elsif @current_result[@current_field] != nil
                      @current_result[@current_field] =
                          [@current_result[@current_field], @current_value]
                    end
                  else
                    @current_result[@current_field] = @current_value
                  end

                  if @current_field == "_raw"
                    @current_result.raw_xml = @current_xml
                  end

                  @current_field = nil
                  @current_value = nil
                end
              end
          },
          # Parse the values inside a results field.
          :field_values => {
              :end_element => lambda do |name|
                if name == "text" || name == "v"
                  if @current_value == nil
                    @current_value = @current_text
                  elsif @current_value.is_a?(Array)
                    @current_value << @current_text
                  else
                    @current_value = [@current_value, @current_text]
                  end

                  if name == "v"
                    @current_xml << "</v>"
                  end

                  @current_text = nil
                  @state = :result
                elsif name == "sg"
                  # <sg> is emitted to delimit text that should be displayed
                  # highlighted. We preserve it in field values.
                  @current_xml << "</sg>"
                end
              end,
              :start_element => lambda do |name, attributes|
                if name == "sg"
                  s = ["sg"] + attributes.sort.map do |entry|
                    key, value = entry
                    "#{key}=\"#{value}\""
                  end
                  text = "<" + s.join(" ") + ">"
                  @current_xml << text
                end
              end,
              :characters => lambda do |text|
                @current_text << text
                @current_xml << Splunk::escape_string(text)
              end
          }
      }
    end

    # Nokogiri methods - all dispatch to the REXML methods.
    def start_element(name, attributes)
      # attributes is an association list. Turn it into a hash
      # that tag_start can use.
      attribute_dict = {}
      attributes.each do |attribute|
        key = attribute.localname
        value = attribute.value
        attribute_dict[key] = value
      end

      tag_start(name, attribute_dict)
    end

    def start_element_namespace(name, attributes=[], prefix=nil, uri=nil, ns=[])
      start_element(name, attributes)
    end

    def end_element(name)
      tag_end(name)
    end

    def end_element_namespace(name, prefix = nil, uri = nil)
      end_element(name)
    end

    def characters(text)
      text(text)
    end

    # REXML methods - all dispatch is done here
    def tag_start(name, attributes)
      # attributes is a hash.
      if @states[@state].has_key?(:start_element)
        @states[@state][:start_element].call(name, attributes)
      end
    end

    def tag_end(name)
      if @states[@state].has_key?(:end_element)
        @states[@state][:end_element].call(name)
      end
    end

    def text(text)
      if @states[@state].has_key?(:characters)
        @states[@state][:characters].call(text)
      end
    end

    # Unused methods in Nokogiri
    def cdata_block(string) end
    def comment(string) end
    def end_document() end
    def error(string) end
    def start_document() end
    def warning(string) end
    # xmldecl declared in REXML list below.

    # Unused methods in REXML
    def attlistdecl(element_name, attributes, raw_content) end
    def cdata(content) end
    def comment(comment) end
    def doctype(name, pub_sys, long_name, uri) end
    def doctype_end() end
    def elementdecl(content) end
    def entity(content) end
    def entitydecl(content) end
    def instruction(name, instruction) end
    def notationdecl(content) end
    def xmldecl(version, encoding, standalone) end
  end

  ##
  # Version of +ResultsReader+ that accepts an external parsing state.
  #
  # +ResultsReader+ sets up its own Fiber for doing SAX parsing of the XML,
  # but for the +MultiResultsReader+, we want to share a single fiber among
  # all the results readers that we create. +PuppetResultsReader+ takes
  # the fiber, is_preview, and fields information from its constructor
  # and then exposes the same methods as ResultsReader.
  #
  # You should never create an instance of +PuppetResultsReader+ by hand. It
  # will be passed back from iterating over a +MultiResultsReader+.
  #
  class PuppetResultsReader < ResultsReader
    def initialize(fiber, is_preview, fields)
      @valid = true
      @iteration_fiber = fiber
      @is_preview = is_preview
      @fields = fields
    end

    def each()
      if !@valid
        raise StandardError.new("Cannot iterate on ResultsReaders out of order.")
      else
        super()
      end
    end

    def invalidate()
      @valid = false
    end
  end

  ##
  # Parser for the XML results sets returned by blocking export jobs.
  #
  # The methods +create_export+ and +create_stream+ on +Jobs+ and +Service+
  # do not return data in quite the same format as other search jobs in Splunk.
  # They will return a sequence of preview results sets, and then (if they are
  # not real time searches) a final results set.
  #
  # +MultiResultsReader+ takes the stream returned by such a call, and provides
  # iteration over each results set, or access to only the final, non-preview
  # results set.
  #
  #
  # *Examples*:
  #     require 'splunk-sdk-ruby'
  #
  #     service = Splunk::connect(:username => "admin", :password => "changeme")
  #
  #     stream = service.jobs.create_export("search index=_internal | head 10")
  #
  #     readers = MultiResultsReader.new(stream)
  #     readers.each do |reader|
  #         puts "New result set (preview=#{reader.is_preview?})"
  #         reader.each do |result|
  #             puts result
  #         end
  #     end
  #
  #     # Alternately
  #     reader = readers.final_results()
  #     reader.each do |result|
  #         puts result
  #     end
  #
  class MultiResultsReader
    include Enumerable

    def initialize(text_or_stream)
      if text_or_stream.nil?
        stream = StringIO.new("")
      elsif !text_or_stream.respond_to?(:read)
        # Strip because the XML libraries can be pissy.
        stream = StringIO.new(text_or_stream.strip)
      else
        stream = text_or_stream
      end

      listener = ResultsListener.new()
      @iteration_fiber = Fiber.new do
        if $splunk_xml_library == :nokogiri
          parser = Nokogiri::XML::SAX::Parser.new(listener)
          # Nokogiri requires a unique root element, which we are fabricating
          # here, while REXML is fine with multiple root elements in a stream.
          edited_stream = ConcatenatedStream.new(
              StringIO.new("<fake-root-element>"),
              XMLDTDFilter.new(stream),
              StringIO.new("</fake-root-element>")
          )
          parser.parse(edited_stream)
        else # Use REXML
          REXML::Document.parse_stream(stream, listener)
        end
      end
    end

    def each()
      enum = Enumerator.new() do |yielder|
        if !@iteration_fiber.nil? # Handle the case of empty files
          begin
            while true
              is_preview = @iteration_fiber.resume
              fields = @iteration_fiber.resume
              reader = PuppetResultsReader.new(@iteration_fiber, is_preview, fields)
              yielder << reader
              # Finish extracting any events that the user didn't read.
              # Otherwise the next results reader will start in the middle of
              # the previous results set.
              reader.skip_remaining_results()
              reader.invalidate()
            end
          rescue FiberError
            # After the last result element, the next evaluation of
            # 'is_preview = @iteration_fiber.resume' above will throw a
            # +FiberError+ when the fiber terminates without yielding any
            # additional values. We handle the control flow in this way so
            # that the final code in the fiber to handle cleanup always gets
            # run.
          end
        end
      end

      if block_given? # Apply the enumerator to a block if we have one
        enum.each() { |e| yield e }
      else
        enum # Otherwise return the enumerator itself
      end
    end

    ##
    # Returns a +ResultsReader+ over only the non-preview results.
    #
    # If you run this method against a real time search job, which only ever
    # produces preview results, it will loop forever. If you run it against
    # a non-reporting system (that is, one that filters and extracts fields
    # from events, but doesn't calculate a whole new set of events), you will
    # get only the first few results, since you should be using the normal
    # +ResultsReader+, not +MultiResultsReader+, in that case.
    #
    def final_results()
      each do |reader|
        if reader.is_preview?
          reader.skip_remaining_results()
        else
          return reader
        end
      end
    end
  end


  ##
  # Stream transformer that filters out XML DTD definitions.
  #
  # +XMLDTDFilter+ takes anything between <? and > to be a DTD. It does no
  # escaping of quoted text.
  #
  class XMLDTDFilter < IO
    def initialize(stream)
      @stream = stream
      @peeked_char = nil
    end

    def close()
      @stream.close()
    end

    def read(n=nil)
      response = ""

      while n.nil? or n > 0
        # First use any element we already peeked at.
        if !@peeked_char.nil?
          response << @peeked_char
          @peeked_char = nil
          if !n.nil?
            n -= 1
          end
          next
        end

        c = @stream.read(1)
        if c.nil? # We've reached the end of the stream
          break
        elsif c == "<" # We might have a DTD definition
          d = @stream.read(1) || ""
          if d == "?" # It's a DTD. Skip until we've consumed a >.
            while true
              q = @stream.read(1)
              if q == ">"
                break
              end
            end
          else # It's not a DTD. Push that ? into lookahead.
            @peeked_char = d
            response << c
            if !n.nil?
              n = n-1
            end
          end
        else # No special behavior
          response << c
          if !n.nil?
            n -= 1
          end
        end
      end
      return response
    end
  end

  ##
  # Returns a stream which concatenates all the streams passed to it.
  #
  class ConcatenatedStream < IO
    def initialize(*streams)
      @streams = streams
    end

    def close()
      @streams.each do |stream|
        stream.close()
      end
    end

    def read(n=nil)
      response = ""
      while n.nil? or n > 0
        if @streams.empty? # No streams left
          break
        else # We have streams left.
          chunk = @streams[0].read(n) || ""
          found_n = chunk.length()
          if n.nil? or chunk.length() < n
            @streams.shift()
          end
          if !n.nil?
            n -= chunk.length()
          end

          response << chunk
        end
      end
      if response == ""
        return nil
      else
        return response
      end
    end
  end
end
