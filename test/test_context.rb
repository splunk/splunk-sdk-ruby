require_relative "test_helper"
require "splunk-sdk-ruby"

include Splunk

# Test the helper functions in test_helper.rb
class TestHelpers < TestCaseWithSplunkConnection
  def test_temporary_name
    assert_true(temporary_name().start_with?("delete-me"))
  end

  def test_set_and_clear_restart_messages()
    service = Context.new(@splunkrc).login()
    assert_false(service.server_requires_restart?)

    set_restart_message(service)
    assert_true(service.server_requires_restart?)

    clear_restart_message(service)
    assert_false(service.server_requires_restart?)
  end
end

class TestContext < TestCaseWithSplunkConnection
  def test_login()
    service = Context.new(@splunkrc)
    service.login()
    assert_logged_in(service)
  end

  def test_login_with_encodings()
    ["ASCII", "UTF-8"].each() do |encoding|
      values = {}
      @splunkrc.each() do |key, value|
        if value.is_a?(String)
          values[key] = value.clone().force_encoding(encoding)
        else
          values[key] = value
        end
      end
      service = Context.new(values).login()
      assert_logged_in(service)
    end
  end

  def test_authenticate_with_token
    service = Context.new(@splunkrc).login()
    token = service.token

    new_arguments = @splunkrc.clone
    new_arguments.delete(:username)
    new_arguments.delete(:password)
    new_arguments[:token] = token

    new_service = Context.new(new_arguments)
    assert_not_nil(new_service.token)
    assert_logged_in(new_service)
  end

  def test_authenticate_with_basic
    new_arguments = @splunkrc.clone
    new_arguments.delete(:username)
    new_arguments.delete(:password)
    new_arguments[:basic] = True

    new_service = Context.new(new_arguments)
    assert_logged_in(new_service)
  end

  def test_failed_login()
    args = @splunkrc.clone()
    args[:username] = args[:username] + "-boris"
    service = Context.new(args)

    assert_raises(SplunkHTTPError) {service.login()}
  end

  def test_multiple_logins_are_nops()
    service = Context.new(@splunkrc).login()
    assert_logged_in(service)

    assert_nothing_raised() {service.login()}
    assert_logged_in(service)
  end

  def test_logout
    service = Context.new(@splunkrc).login()
    assert_logged_in(service)

    service.logout()
    assert_not_logged_in(service)

    service.login()
    assert_logged_in(service)
  end

  def test_connect()
    service = Context.new(@splunkrc).login()
    socket = service.connect()
    # Send a manual HTTP request
    socket.write("GET /services/data/indexes HTTP/1.1\r\n")
    socket.write("Authorization: Splunk #{service.token}\r\n")
    socket.write("\r\n")
    response = socket.readlines()
    assert_equal("HTTP/1.1 200 OK", response[0].strip)
  end

  def test_server_accepting_connections?
    values = @splunkrc.clone()
    values[:port] = 8000
    service = Context.new(values)
    assert_false(service.server_accepting_connections?)

    service = Context.new(@splunkrc)
    assert_true(service.server_accepting_connections?)
  end

  def test_info
    assert_true(@service.info.has_key?("version"))
  end

  def test_splunk_version
    version = @service.splunk_version
    assert_true(version.is_a?(Array))
    version.each() do |v|
      assert_true(v.is_a?(Integer))
    end
  end

  def test_url_encoding_of_characters_in_usernames
    name = temporary_name() + "/\441@"
    begin
      @service.request(:namespace => Splunk::namespace(:sharing => "user", :owner => name, :app => name))
      fail("Didn't receive an error.")
    rescue SplunkHTTPError => err
      assert_equal(404, err.code)
      assert_equal("User does not exist: " + name, err.detail)
    end
  end

end
