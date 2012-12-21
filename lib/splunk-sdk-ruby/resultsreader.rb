require 'nokogiri'

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

    def initialize(text_or_stream)
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
        parser = Nokogiri::XML::SAX::Parser.new(listener)
        @iteration_fiber = Fiber.new do
          parser.parse(stream)
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
                end
              end,
              :characters => lambda do |text|
                @current_scratch << text
              end
          }
      }
    end

    def start_element(name, attributes)
      if @states[@state].has_key?(:start_element)
        attribute_dict = {}
        attributes.each do |attribute|
          key, value = attribute
          attribute_dict[key] = value
        end
        @states[@state][:start_element].call(name, attribute_dict)
      end
    end

    def end_element(name)
      if @states[@state].has_key?(:end_element)
        @states[@state][:end_element].call(name)
      end
    end

    def characters(text)
      if @states[@state].has_key?(:characters)
        @states[@state][:characters].call(text)
      end
    end

  end

  #
  #
  #
  #  class MyListener < Nokogiri::XML::SAX::Document
  #    def initialize(block)
  #      @block = block
  #    end
  #
  #    def start_element(name, attrs)
  #      if name == "section"
  #        @section = alist_find(attrs, "name")
  #      elsif name == "item"
  #          @current_item = {}
  #      elsif !@current_item.nil?
  #        @current_field = name
  #         
  #      end
  #
  #    end
  #
  #
  #    def characters(text)
  #
  #      if !@current_field.nil?
  #        @current_item[@current_field] = text
  #
  #      end
  #
  #    end
  #
  #
  #    def end_element(name)
  #
  #      if name == "section"
  #        @section = nil
  #
  #      elsif name == "item"
  #        @block.call(@current_item)
  #        @current_item = nil
  #
  #      elsif !@current_item.nil?
  #        @current_field = nil
  #
  #      end
  #
  #    end
  #  end
  #
  #  class MyStreamer
  #    def each(&block)
  #      listener = MyListener.new(block)
  #      parser = Nokogiri::XML::SAX::Parser.new(listener)
  #      source = File.new("data.xml")
  #      parser.parse(source)
  #    end
  #  end
  #
  #  s = MyStreamer.new()
  #  s.each { |result| puts "Returned: #{result}" }
  #
  #
  #end
end