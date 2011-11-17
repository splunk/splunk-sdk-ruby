require_relative 'aloader'

class SplunkHTTPError < SplunkError
  attr_reader :status, :reason, :headers, :body, :detail

  def initialize(response)
    @body = response.to_str

    doc = LibXML::XML::Parser.string(@body).parse
    @detail = doc.find('/messages/msg').last.content

    al = AtomResponseLoader::load_text(@body)

    @status = al['status']
    @reason = al['reason']
    @headers = response.headers

    detail.nil? ? detail_msg = "" : detail_msg = @detail
    message = "HTTP #{@status.to_str} #{@reason}#{detail_msg}"

    super.intialize message
  end
end