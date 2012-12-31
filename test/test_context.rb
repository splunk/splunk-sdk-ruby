require_relative "test_helper"
require "splunk-sdk-ruby"

include Splunk

class TestContext < SplunkTestCase
  def assert_logged_in(context)
    assert_nothing_raised do
      # A request to data/indexes requires you to be logged in.
      context.request(:method=>:GET,
                      :resource=>["data", "indexes"])
    end
  end

  def assert_not_logged_in(context)
    begin
      context.request(:method=>:GET,
                      :resource=>["data", "indexes"])
    rescue SplunkHTTPError => err
      assert_equal(401, err.code, "Expected HTTP status code 401, found: #{err.code}")
    else
      fail("Context is logged in.")
    end
  end

  def test_login()
    context = Context.new(@splunkrc)
    context.login()
    assert_logged_in(context)
  end

  def test_login_with_encodings()
    ["ASCII", "UTF-8"].each() do |encoding|
      values = {}
      @splunkrc.each() do |key, value|
        values[key] = value.clone().force_encoding(encoding)
      end
      context = Context.new(values).login()
      assert_logged_in(context)
    end
  end

  def test_authenticate_with_token
    context = Context.new(@splunkrc).login()
    token = context.token

    new_arguments = @splunkrc.clone
    new_arguments.delete(:username)
    new_arguments.delete(:password)
    new_arguments[:token] = token

    new_context = Context.new(new_arguments)
    assert_not_nil(new_context.token)
    assert_logged_in(new_context)
  end

  def test_failed_login()
    args = @splunkrc.clone()
    args[:username] = args[:username] + "-boris"
    context = Context.new(args)

    assert_raises(SplunkHTTPError) {context.login()}
  end

  def test_multiple_logins_are_nops()
    context = Context.new(@splunkrc).login()
    assert_logged_in(context)

    assert_nothing_raised() {context.login()}
    assert_logged_in(context)
  end

  def test_logout
    context = Context.new(@splunkrc).login()
    assert_logged_in(context)

    context.logout()
    assert_not_logged_in(context)

    context.login()
    assert_logged_in(context)
  end

  def test_connect()
    context = Context.new(@splunkrc).login()
    socket = context.connect()
    # Send a manual HTTP request
    socket.write("GET /services/data/indexes HTTP/1.1\r\n")
    socket.write("Authorization: Splunk #{context.token}\r\n")
    socket.write("\r\n")
    response = socket.readlines()
    assert_equal("HTTP/1.1 200 OK", response[0].strip)
  end
end
