require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class ConfigurationFileTestCase < SplunkTestCase
  def setup
    super
    # We cannot delete configuration files from the REST API
    # so we create a temporary application to do our manipulation
    # in. When we delete it at the end of the test run, the
    # configuration modifications will be deleted as well.
    @container_app_name = temporary_name()
    @service.apps.create(@container_app_name)

    # Now reconnect in the test app context.
    app_service_args = @splunkrc.clone()
    app_service_args[:namespace] =
        namespace("app", @container_app_name)
    @app_service = Splunk::Service.new(app_service_args).login()
    @confs = @app_service.confs
  end

  def teardown
    if @service.server_requires_restart?
      fail("Test left Splunk in a state requiring restart.")
    end

    @service.apps.delete(@container_app_name)
    if @service.server_requires_restart?
      clear_restart_message(@service)
    end

    super
  end

  def test_create_and_delete
    file_name = temporary_name()
    assert_false(@confs.has_key?(file_name))
    assert_false(@confs.contains?(file_name))
    assert_false(@confs.member?(file_name))
    assert_false(@confs.key?(file_name))
    assert_false(@confs.include?(file_name))

    conf = @confs.create(file_name)
    assert_equal(file_name, conf.name)
    assert_equal(0, conf.length)

    assert_true(@confs.has_key?(file_name))
    assert_true(@confs.contains?(file_name))
    assert_true(@confs.member?(file_name))
    assert_true(@confs.key?(file_name))
    assert_true(@confs.include?(file_name))

    assert_raises(Splunk::IllegalOperation) {@confs.delete(file_name)}
  end

  def test_fetch
    file_name = temporary_name()
    created_conf = @confs.create(file_name)

    fetched_conf = @confs.fetch(file_name)
    assert_true(fetched_conf.is_a?(ConfigurationFile))
    assert_equal(created_conf.name, fetched_conf.name)

    bracket_fetched_conf = @confs[file_name]
    assert_true(fetched_conf.is_a?(ConfigurationFile))
    assert_equal(created_conf.name, bracket_fetched_conf.name)
  end

  def test_each_and_values
    each_names = []
    @confs.each() { |entity| each_names << entity.name }

    values_names = @confs.values().map() {|e| e.name}

    assert_false(each_names.empty?)
    assert_equal(each_names, values_names)
  end

  def test_create_and_delete_stanzas
    file_name = temporary_name()
    conf = @confs.create(file_name)

    assert_equal(0, conf.length())

    n = 5 + rand(5)
    stanza_names = []
    (1..n).each() do
      stanza_name = temporary_name()
      stanza_names << stanza_name
      conf.create(stanza_name)
    end

    assert_equal(n, conf.length())

    stanza_names.each() do |name|
      conf.delete(name)
      n -= 1
      assert_equal(n, conf.length())
    end
  end

  def test_each
    @confs.each() do |configuration_file|
      assert_true(configuration_file.is_a?(ConfigurationFile))
    end
  end

  def test_submit_to_stanza
    file_name = temporary_name()
    conf = @confs.create(file_name)

    stanza_name = temporary_name()
    stanza = conf.create(stanza_name)

    assert_equal(0, stanza.length())
    stanza.submit(:boris => "natasha", :hilda => "moose on the roof")
    stanza.refresh()
    assert_equal(2, stanza.length())
    assert_equal("natasha", stanza["boris"])
    assert_equal("moose on the roof", stanza["hilda"])
  end
end