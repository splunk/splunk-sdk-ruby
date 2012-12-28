require_relative 'test_helper'

require 'splunk-sdk-ruby'

class MockResponse
  include Enumerable

  attr_reader :code, :message, :body

  def initialize(code, message, headers, body)
    @code = code
    @message = message
    @headers = headers
    @body = body
  end

  def each(&block)
    @headers.each(&block)
  end
end

include Splunk

class TestHTTPError < SplunkTestCase
  def test_error_with_empty_message
    response = MockResponse.new(code=400, message="Meep",
                                headers={}, body="")
    err = SplunkHTTPError.new(response)
    assert_nil(err.detail)
    assert_equal(response.code, err.code)
    assert_equal(response.message, err.reason)
    assert_equal("HTTP 400 Meep: ", err.message)
  end

  def test_error_with_message
    response = MockResponse.new(
        code=400, message="Index Error", headers={},
        body = "<response><messages>" +
            "<msg type=\"ERROR\">In handler &apos;indexes&apos;: " +
            "Index name=boris already exists</msg></messages></response>")
    err = SplunkHTTPError.new(response)
    assert_equal("In handler 'indexes': Index name=boris already exists",
                 err.detail)
    assert_equal(400, err.code)
    assert_equal("Index Error", err.reason)
    assert_equal([], err.headers)
    assert_equal("HTTP 400 Index Error: In handler 'indexes': " +
                     "Index name=boris already exists",
                 err.message)
  end

end