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

require 'test-unit'

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
    @service = Service.new(@splunkrc).login()
    @installed_apps = []

    if @service.server_requires_restart?
      fail("Previous test left server in a state requiring a restart.")
    end
  end

  def teardown
    if @service.server_requires_restart?()
      fail("Test left server in a state requiring restart.")
    end

    @installed_apps.each() do |app_name|
      @service.apps.delete(app_name)
      assert_eventually_true() do
        !@service.apps.has_key?(app_name)
      end
      if @service.server_requires_restart?
        clear_restart_message(@service)
      end
    end

    @installed_apps.clear()

    super
  end

  def assert_eventually_true(timeout=30, &block)
    Timeout::timeout(timeout) do
      while !block.call()
        sleep(0.2)
      end
    end
  end

  def assert_logged_in(service)
    assert_nothing_raised do
      # A request to data/indexes requires you to be logged in.
      service.request(:method=>:GET,
                      :resource=>["data", "indexes"])
    end
  end

  def assert_not_logged_in(service)
    begin
      service.request(:method=>:GET,
                      :resource=>["data", "indexes"])
    rescue SplunkHTTPError => err
      assert_equal(401, err.code, "Expected HTTP status code 401, found: #{err.code}")
    else
      fail("Context is logged in.")
    end
  end

  # Clear any restart messages on _service_.
  #
  # If there was no restart message, raises an error. (We want all the restarts
  # and restart messages carefully controlled in the test suite.)
  #
  def clear_restart_message(service)
    if !service.server_requires_restart?
        raise StandardError.new("Tried to clear restart message " +
                                    "when there was none.")
    end
    begin
      service.request(:method => :DELETE,
                      :resource => ["messages", "restart_required"])
    rescue SplunkHTTPError => err
      if err.code != 404
        raise err
      end
    end
  end

  def has_app_collection?(service)
    collection_name = 'sdk-app-collection'
    return service.apps.has_key?(collection_name)
  end

  def install_app_from_collection(name)
    collection_name = 'sdk-app-collection'
    if !@service.apps.has_key?(collection_name)
      raise StandardError("#{collection_name} not installed in Splunk.")
    end

    app_path = path_in_app(collection_name, ["build", name+".tar"])
    args = {"update" => 1, "name" => app_path}
    begin
      @service.request(:method => :POST,
                       :resource => ["apps", "appinstall"],
                       :body => args)
      @installed_apps << name
    rescue SplunkHTTPError => err
      if err.code == 40
        raise StandardError("App #{name} not found in app collection")
      else
        raise err
      end
    end
  end

  # Return a path to *path_components* in *app_name*.
  #
  # `path_in_app` is used to refer to files in applications installed with
  # `install_app_from_collection`. For example, the app `file_to_upload` in
  # the collection contains `log.txt`. To get the path to it, call::
  #
  # path_in_app('file_to_upload', ['log.txt'])
  #
  # The path to `setup.xml` in `has_setup_xml` would be fetched with::
  #
  # path_in_app('has_setup_xml', ['default', 'setup.xml'])
  #
  # path_in_app` figures out the correct separator to use (based on whether
  # splunkd is running on Windows or Unix) and joins the elements in
  # *path_components* into a path relative to the application specified by
  # *app_name*.
  #
  # *path_components* should be a list of strings giving the components.
  # This function will try to figure out the correct separator (/ or \)
  # for the platform that splunkd is running on and construct the path
  # as needed.
  #
  # :return: A string giving the path.
  #
  def path_in_app(app_name, path_components)
    splunk_home = @service.settings["SPLUNK_HOME"]
    if splunk_home.include?("\\")
      # This clause must come first, since Windows machines may
      # have mixed \ and / in their paths.
      separator = "\\"
    elsif splunk_home.include?("/")
      separator = "/"
    else
      raise StandardError("No separators in $SPLUNK_HOME. Can't determine " +
                              "what file separator to use.")
    end

    app_path = ([splunk_home, "etc", "apps", app_name] + path_components).
        join(separator)
    return app_path
  end


  # Create a new restart message on _service_.
  #
  # Optionally you can specify a value for the restart message, or it will
  # default to "Ruby SDK test suite asked for a restart."
  #
  def set_restart_message(service,
                          message="Ruby SDK test suite asked for a restart.")
    service.request(:method => :POST,
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
  def checked_restart(service)
    if !service.server_requires_restart?
      raise StandardError("Tried to restart a Splunk instance that" +
                              " does not need it.")
    else
      service.restart(DEFAULT_RESTART_TIMEOUT)
    end
  end

  # Restarts a Splunk instance whether it needs it or not.
  #
  def unchecked_restart(service)
    service.restart(DEFAULT_RESTART_TIMEOUT)
  end
end