require 'rubygems'

require_relative 'aloader'
require_relative 'splunk_error'


module Splunk
  class SplunkHTTPError < SplunkError
    attr_reader :status, :reason, :code, :headers, :body, :detail

    def initialize(response)
      @body = response.body
      doc = Nokogiri::XML(@body)
      temp_detail = doc.xpath('//msg').last

      if temp_detail.nil?
        @detail = nil
      else
        @detail = temp_detail.content
      end

      al = AtomResponseLoader::load_text(@body)

      @code = response.code
      @status = al['status'] || ''
      @reason = al['reason'] || ''
      @headers = response.headers

      detail_msg = @detail || ''
      message = "HTTP #{@status.to_str} #{@reason}#{detail_msg}"

      super message
    end
  end
end
