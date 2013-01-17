#--
# Copyright 2011-2012 Splunk, Inc.
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
# +resultsreader.rb+ provides +ResultsReader+, an object to incrementally parse
# XML streams of results from Splunk search jobs into Ruby objects.
#
# By default, +ResultsReader+ will try to use Nokogiri for XML parsing. If
# Nokogiri isn't available, it will fall back to REXML, which ships with Ruby
# 1.9. See +xml_shim.rb+ for how to alter this behavior.
#

require 'stringio'

require_relative 'xml_shim'

module Splunk
  # ResultsReader parses Splunk's XML format for results into Ruby objects.
  #
  # You can use both Nokogiri and REXML. By default, the +ResultsReader+ will
  # try to use Nokogiri, and if it is not available will fall back to REXML. If
  # you want other behavior, see +xml_shim.rb+ for how to set the XML library.
  #
  # +ResultsReader is an Enumerable, so it has methods such as +each+ and
  # +each_with_index+. However, since it's a stream parser, once you iterate
  # through it once, it will thereafter be empty.
  #
  # The ResultsReader object has two additional methods:
  #
  # * `is_preview?` return a boolean value saying if these results are
  #   a preview from an unfinished search or not.
  # * `fields` returns an array of all the fields that may appear in a result
  #   in this set, in the order they should be displayed (if you're going
  #   to make a table or the like).
  #
  # *Example*:
  #
  #     require 'splunk-sdk-ruby'
  #
  #     service = Splunk::connect(:username => "admin", :password => "changeme")
  #
  #     stream = service.jobs.create_oneshot("search index=_internal | head 10")
  #     reader = ResultsReader.new(stream)
  #     puts reader.is_preview?
  #     # Prints: false
  #     reader.each do |result|
  #       puts result
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
    # Returns: an +Array+ of +String+s.
    #
    attr_reader :fields

    def initialize(text_or_stream)
      if text_or_stream.nil?
        stream = StringIO.new("")
      elsif !text_or_stream.respond_to?(:read)
        stream = StringIO.new(text_or_stream.strip)
      else
        stream = text_or_stream
      end

      if stream.eof?
        @is_preview = nil
        @fields = []
      else
        # We use a SAX parser. listener is the event handler, but a SAX
        # parser won't usually transfer control during parsing. In order
        # to incrementally return results as we parse, we have to put
        # the parser into a Fiber from which we can yield.
        listener = ResultsListener.new()
        @iteration_fiber = Fiber.new do
          if $splunk_xml_library == :nokogiri
            parser = Nokogiri::XML::SAX::Parser.new(listener)
            parser.parse(stream)
          else # Use REXML
            REXML::Document.parse_stream(stream, listener)
          end
        end

        @is_preview, @fields = @iteration_fiber.resume
      end
    end

    def each()
      enum = Enumerator.new() do |yielder|
        if !@iteration_fiber.nil? # Handle the case of empty files
          result = @iteration_fiber.resume
          while result != nil
            yielder << result
            result = @iteration_fiber.resume
          end
        end
      end

      if block_given? # Apply the enumerator to a block if we have one
        enum.each() { |e| yield e }
      else
        enum # Otherwise return the enumerator itself
      end
    end
  end

  ##
  # ResultsListener is the SAX event handler for ResultsReader.
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
  # a preview, and it has read the field order. Then it calls `Fiber.yield`
  # to return those two values. When `Fiber.resume` is called, it will
  # continue and thereafter call `Fiber.yield` with every result as it
  # finishes parsing it.
  #
  class ResultsListener # :nodoc:
    def initialize()
      @fields = []
      @header_sent = false
      @is_preview = nil
      @state = :base
      @states = {
          # Toplevel state.
          :base => {
              :start_element => lambda do |name, attributes|
                if name == "results"
                  @is_preview = attributes["preview"] == "1"
                elsif name == "fieldOrder"
                  @state = :field_order
                elsif name == "result"
                  @state = :result
                  @current_offset = Integer(attributes["offset"])
                  @current_result = {}
                end
              end,
              :end_element => lambda do |name|
                if name == "results" and !@header_sent
                  @header_sent = true
                  Fiber.yield @is_preview, @fields
                end
              end
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
                  @header_sent = true
                  Fiber.yield @is_preview, @fields
                end
              end,
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
                  @current_scratch = ""
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
                    @current_value = @current_scratch
                  elsif @current_value.is_a?(Array)
                    @current_value << @current_scratch
                  else
                    @current_value = [@current_value, @current_scratch]
                  end

                  @current_scratch = nil
                  @state = :result
                elsif name == "sg"
                  # <sg> is emitted to delimit text that should be displayed
                  # highlighted. We preserve it in field values.
                  @current_scratch << "</sg>"
                end
              end,
              :start_element => lambda do |name, attributes|
                if name == "sg"
                  s = ["sg"] + attributes.sort.map do |entry|
                    key, value = entry
                    "#{key}=\"#{value}\""
                  end
                  text = "<" + s.join(" ") + ">"
                  @current_scratch << text
                end
              end,
              :characters => lambda do |text|
                @current_scratch << text
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
end
