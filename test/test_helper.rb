if ENV.has_key?("COVERAGE")
  require "simplecov"
  SimpleCov.start() do
    add_filter("test")
  end
end

# This line is required to let RubyMine run the test suite,
# since otherwise random packages load other random packages
# in random order and clobber RubyMine's configuration.
# See http://youtrack.jetbrains.com/issue/RUBY-11922
$:.unshift($:.select {|i| i.include? '/patch/'}).flatten!

require 'test/unit'

$:.unshift File.expand_path(File.join([File.dirname(__FILE__), "..", "lib"]))

def read_splunkrc
  file = File.new(File.expand_path("~/.splunkrc"))
  options = {
      :host => 'localhost',
      :port => 8089,
      :username => 'admin',
      :password => 'changeme',
      :scheme => 'https',
      :version => '5.0'
  }
  file.readlines.each do |raw_line|
    line = raw_line.strip()
    if line.start_with?("\#") or line.length == 0
      next
    else
      raw_key, raw_value = line.split('=', limit=2)
      key = raw_key.strip().intern
      value = raw_value.strip()

      if key == 'port'
        value = Integer(value)
      end

      options[key] = value
    end
  end

  options
end

def nokogiri_available?
  begin
    require 'nokogiri'
    return true
  rescue LoadError
    return false
  end
end

require 'securerandom'
def temporary_name
  return "delete-me-" + SecureRandom.uuid()
end

DEFAULT_RESTART_TIMEOUT = 500 # seconds

class SplunkTestCase < Test::Unit::TestCase
  def setup
    super
    @splunkrc = read_splunkrc()
    @context = Context.new(@splunkrc).login()

    if @context.server_requires_restart?
      fail("Previous test left server in a state requiring a restart.")
    end
  end

  def teardown
    if @context.server_requires_restart?()
      puts "Test left server in a state requiring restart."
      checked_restart(@context)
    end

    super
  end

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

  # Clear any restart messages on _context_.
  #
  # If there was no restart message, raises an error. (We want all the restarts
  # and restart messages carefully controlled in the test suite.)
  #
  def clear_restart_message(context)
    if !context.server_requires_restart?
        raise StandardError.new("Tried to clear restart message " +
                                    "when there was none.")
    end
    begin
      context.request(:method => :DELETE,
                      :resource => ["messages", "restart_required"])
    rescue SplunkHTTPError => err
      if err.code != 404
        raise err
      end
    end
  end

  # Create a new restart message on _context_.
  #
  # Optionally you can specify a value for the restart message, or it will
  # default to "Ruby SDK test suite asked for a restart."
  #
  def set_restart_message(context,
                          message="Ruby SDK test suite asked for a restart.")
    context.request(:method => :POST,
            :namespace => namespace(),
            :resource => ["messages"],
            :body => {"name" => "restart_required",
                      "value" => "Message set by restart method" +
                          " of the Splunk Ruby SDK"})
  end

  # Restart Splunk and wait for it to come back up, but only if it needs it.
  #
  # Throws an error if this is called on a Splunk instance that does not
  # need to be restarted.
  #
  def checked_restart(context)
    if !context.server_requires_restart?
      raise StandardError("Tried to restart a Splunk instance that" +
                              " does not need it.")
    else
      context.restart(DEFAULT_RESTART_TIMEOUT)
    end
  end

  # Restarts a Splunk instance whether it needs it or not.
  #
  def unchecked_restart(context)
    context.restart(DEFAULT_RESTART_TIMEOUT)
  end
end