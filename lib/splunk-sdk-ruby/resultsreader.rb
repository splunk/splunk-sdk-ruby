require 'rexml/document'
require 'rexml/streamlistener'
$xml_library = :rexml

if !(ENV['RUBY_XML_LIBRARY'] == 'rexml')
  begin
    require 'nokogiri'
    $xml_library = :nokogiri
  rescue LoadError
  end
end

# Note: run the SAX parser in a Fiber and have it yield events.
# The Fiber must be run up to the first result, set all the metadata,
# then yield.
# All subsequent yields should yield a message or a result.
# Do I want a proper message vs result type in the parsing? That would
# probably be a good idea.

module Splunk
  public
  class ResultsReader
    include Enumerable

    def is_preview?
      return @is_preview
    end

    attr_reader :fields

    def initialize(text_or_stream, xml_library=$xml_library)
      if !text_or_stream.respond_to?(:read)
        stream = StringIO(text_or_stream.strip)
      else
        stream = text_or_stream
      end

      if stream.eof?
        @is_preview = nil
        @fields = []
      else
        listener = ResultsListener.new
        @iteration_fiber = Fiber.new do
          if xml_library == :nokogiri
            parser = Nokogiri::XML::SAX::Parser.new(listener)
            parser.parse(stream)
          else
            REXML::Document.parse_stream(stream, listener)
          end
        end

        @is_preview, @fields = @iteration_fiber.resume
      end
    end

    def each(&block)
      if @iteration_fiber.nil? # Handle the case of empty files
        return
      else
        result = @iteration_fiber.resume
        while result != nil
          block.call(result)
          result = @iteration_fiber.resume
        end
      end
    end
  end

  class ResultsListener < Nokogiri::XML::SAX::Document
    def initialize()
      @fields = []
      @header_sent = false
      @is_preview = nil
      @state = :base
      @states = {
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

    def start_element(name, attributes) # Nokogiri version
      # attributes is an association list. Turn it into a hash
      # that tag_start can use.
      attribute_dict = {}
      attributes.each do |attribute|
        key, value = attribute
        attribute_dict[key] = value
      end
      tag_start(name, attribute_dict)
    end

    def tag_start(name, attributes) # REXML version
      # attributes is a hash.
      if @states[@state].has_key?(:start_element)
        @states[@state][:start_element].call(name, attributes)
      end
    end

    def end_element(name)
      if @states[@state].has_key?(:end_element)
        @states[@state][:end_element].call(name)
      end
    end

    def tag_end(name)
      end_element(name)
    end

    def characters(text)
      if @states[@state].has_key?(:characters)
        @states[@state][:characters].call(text)
      end
    end

    def text(text)
      characters(text)
    end

  end
end
