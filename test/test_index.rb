require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class IndexTestCase < TestCaseWithSplunkConnection
  def setup
    super

    @index_name = temporary_name()
    @index = @service.indexes.create(@index_name)
    assert_eventually_true() do
      @index.refresh()["disabled"] == "0"
    end
  end

  def teardown
    if @service.splunk_version[0] >= 5
      @service.indexes.
          select() { |index| index.name.start_with?("delete-me")}.
          each() do |index|
        if index.fetch("disabled") == "1"
          index.enable()
        end
        index.delete()
      end
    end

    super
  end

  def test_delete
    if @service.splunk_version[0] < 5
      return
    end
    assert_true(@service.indexes.has_key?(@index_name))
    @service.indexes.delete(@index_name)
    assert_eventually_true() do
      !@service.indexes.has_key?(@index_name)
    end
  end

  def test_disable_enable
    @index.disable()
    checked_restart(@service)
    @index.refresh()
    assert_equal('1', @index["disabled"])

    @index.enable()
    @index.refresh()
    assert_equal("0", @index["disabled"])
  end

  def test_submit_via_attach
    event_count = Integer(@index["totalEventCount"])
    socket = @index.attach()
    socket.write("Hello, Boris!\r\n")
    socket.close()
    assert_eventually_true(10) do
      Integer(@index.refresh()["totalEventCount"]) == event_count+1
    end
  end

  def test_submit_and_clean
    original_count = Integer(@index.refresh()["totalEventCount"])
    @index.submit("Boris 1", :sourcetype => "Boris", :host => "Meep")
    @index.submit("Boris 2", :sourcetype => "Boris", :host => "Meep")
    assert_eventually_true(100) do
      Integer(@index.refresh()["totalEventCount"]) == original_count + 2
    end

    @index.clean(timeout=500)
    assert_equal(0, Integer(@index.refresh()["totalEventCount"]))
  end

  def test_upload
    if !has_app_collection?(@service)
        print "Test requires sdk-app-collection. Skipping."
        return
    end

    install_app_from_collection("file_to_upload")

    original_count = Integer(@index.refresh().fetch("totalEventCount"))
    @index.upload(path_in_app("file_to_upload", ["log.txt"]))

    assert_eventually_true() do
      Integer(@index.refresh()["totalEventCount"]) == original_count + 4
    end
  end
end