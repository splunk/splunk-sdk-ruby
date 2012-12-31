require_relative "test_helper"
require "splunk-sdk-ruby"

include Splunk

# Test the helper functions in test_helper.rb
class TestHelpers < SplunkTestCase
  def test_temporary_name
    assert_true(temporary_name().start_with?("delete-me"))
  end

  def test_set_and_clear_restart_messages()
    context = Context.new(@splunkrc).login()
    assert_false(context.server_requires_restart?)

    set_restart_message(context)
    assert_true(context.server_requires_restart?)

    clear_restart_message(context)
    assert_false(context.server_requires_restart?)
  end
end

class TestContext < SplunkTestCase
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

  def test_server_accepting_connections?
    values = @splunkrc.clone()
    values[:port] = 10253
    context = Context.new(values)
    assert_false(context.server_accepting_connections?)

    context = Context.new(@splunkrc)
    assert_true(context.server_accepting_connections?)
  end
end
