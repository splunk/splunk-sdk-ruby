require_relative 'xml_shim'

module Splunk
  class SplunkHTTPError < StandardError
    attr_reader :reason, :code, :headers, :body, :detail

    def initialize(response)
      @body = response.body
      begin
        @detail = text_at_xpath("//msg", response.body)
      #rescue
      #  @detail = nil
      end
      @reason = response.message
      @code = Integer(response.code)
      @headers = response.each().to_a()

      super("HTTP #{@code.to_s} #{@reason}: #{@detail || ""}")
    end
  end
end
