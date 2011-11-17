require_relative 'aloader'
require_relative 'splunk_error'

class SplunkHTTPError < SplunkError
  attr_reader :status, :reason, :headers, :body, :detail

  def initialize(response)
    @body = response.body

    doc = LibXML::XML::Parser.string(@body).parse
    @detail = doc.find('//msg').last.content

    al = AtomResponseLoader::load_text(@body)

    @status = al['status']
    @status = "" if @status.nil?
    @reason = al['reason']
    @reason = "" if @reason.nil?
    @headers = response.headers

    detail.nil? ? detail_msg = "" : detail_msg = @detail
    message = "HTTP #{@status.to_str} #{@reason}#{detail_msg}"
    super message
  end
end