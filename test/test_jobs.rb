require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

QUERY = "search index=_internal | head 3"
JOB_ARGS = {:earliest_time => "-1m", :latest_time => "now",
            :status_buckets => 10}

class JobsTestCase < TestCaseWithSplunkConnection
  def test_create_with_garbage_fails
    assert_raises(SplunkHTTPError) do
      @service.jobs.create("aweaj;awfaw faf'adf")
    end
  end

  def test_create_and_idempotent_cancel
    jobs = @service.jobs
    job = jobs.create(QUERY)
    assert_true(jobs.has_key?(job.sid))
    job.cancel()
    assert_eventually_true() { !jobs.has_key?(job.sid) }
    job.cancel() # Cancel twice should be a nop
  end

  ##
  # There is a convenience method on service to create an asynchronous
  # search job. Test it the same way.
  #
  def test_service_create_and_idempotent_cancel
    jobs = @service.jobs
    job = @service.create_search(QUERY)
    assert_true(jobs.has_key?(job.sid))
    job.cancel()
    assert_eventually_true() { !jobs.has_key?(job.sid) }
    job.cancel() # Cancel twice should be a nop
  end

  def test_create_with_exec_mode_fails
    assert_raises(ArgumentError) do
      @service.jobs.create(QUERY, :exec_mode => "oneshot")
    end
  end

  def test_oneshot
    jobs = @service.jobs
    stream = jobs.create_oneshot(QUERY)
    results = ResultsReader.new(stream)
    assert_false(results.is_preview?)
    events = results.to_a()
    assert_equal(3, events.length())
  end

  ##
  # Test that Service#create_oneshot properly creates a oneshot search.
  #
  def test_oneshot_on_service
    jobs = @service.jobs
    stream = @service.create_oneshot(QUERY)
    results = ResultsReader.new(stream)
    assert_false(results.is_preview?)
    events = results.to_a()
    assert_equal(3, events.length())
  end

  def test_oneshot_with_garbage_fails
    assert_raises(SplunkHTTPError) do
      @service.jobs.create_oneshot("abcwrawerafawf 'adfad'faw")
    end
  end

  def test_export_with_garbage_fails
    assert_raises(SplunkHTTPError) do
      @service.jobs.create_export("abavadfa;ejwfawfasdfadf wfw").to_a()
    end
  end

  def test_export
    stream = @service.jobs.create_export(QUERY)
    assert_true(stream.is_a?(ExportStream))
    results = ResultsReader.new(stream).to_a()
    assert_equal(3, results.length())
  end

  ##
  # Test that the convenience method Service#create_export behaves the same
  # way as Jobs#create_export.
  #
  def test_export_on_service
    stream = @service.create_export(QUERY)
    results = ResultsReader.new(stream).to_a()
    assert_equal(3, results.length())
  end

  ##
  # Test that ResultsReader parses reporting export searches correctly
  # (by only returning the final, nonpreview results).
  #
  def test_export_on_reporting_search
    stream = @service.create_export("search index=_internal earliest=-2d | stats count(_raw) by method")
    results = ResultsReader.new(stream).to_a()
    assert_true(3 >= results.length())
  end

  ##
  # Test that oneshot jobs have no <sg> elements in the XML they return
  # by default.
  #
  def test_oneshot_has_no_segmentation_by_default
    omit_if(@service.splunk_version[0] == 4)
    stream = @service.create_oneshot("search index=_internal GET | head 3")
    assert_false(stream.include?("<sg"))
  end

  ##
  # Are <sg> elements returned in the XML from a oneshot job when we pass
  # the option segmentation=raw?
  #
  def test_oneshot_has_forced_segmentation
    omit_if(@service.splunk_version[0] == 4)
    stream = @service.create_oneshot("search index=_internal GET | head 3",
                                     :segmentation => "raw")
    assert_true(stream.include?("<sg"))
  end

  ##
  # Test that export jobs have no <sg> elements in the XML they return by
  # default.
  #
  def test_export_has_no_segmentation_by_default
    omit_if(@service.splunk_version[0] == 4)
    stream = @service.create_export("search index=_internal GET | head 3")
    assert_false(stream.include?("<sg"))
  end

  ##
  # Export jobs should have <sg> elements in the XML they return when a
  # value is passed to the segmentation argument to make it so.
  #
  def test_export_has_forced_segmentation
    omit_if(@service.splunk_version[0] == 4)

    stream = @service.create_export("search index=_internal GET | head 3",
                                     :segmentation => "raw")
    assert_true(stream.include?("<sg"))
  end

  ##
  # Results and preview on a search job should have no segmentation
  # by default.
  #
  def test_asynchronous_job_has_no_segmentation_by_default
    omit_if(@service.splunk_version[0] == 4)
    job = @service.jobs.create("search index=_internal GET | head 3")
    until job.is_done?()
      sleep(0.1)
    end
    assert_false(job.events().include?("<sg"))
    assert_false(job.preview().include?("<sg"))
  end

  ##
  # Results and preview on a search job should have segmentation when
  # it is forced.
  #
  def test_asynchronous_job_has_segmentation_when_forced
    omit_if(@service.splunk_version[0] == 4)
    job = @service.jobs.create("search index=_internal GET | head 3")
    until job.is_done?()
      sleep(0.1)
    end
    assert_true(job.events(:segmentation => "raw").include?("<sg"))
    assert_true(job.preview(:segmentation => "raw").include?("<sg"))
  end

  def test_each_and_values
    jobs = Jobs.new(@service)

    created_jobs = []

    (1..3).each() do |i|
      job = jobs.create("search index=_internal | head #{i}")
      while !job.is_ready?
        sleep(0.1)
      end
      created_jobs << job
    end

    each_jobs = []
    jobs.each() do |job|
      assert_false(job.name.empty?)
      each_jobs << job.sid
    end

    values_jobs = jobs.values().map() { |j| j.sid }
    assert_equal(each_jobs, values_jobs)

    created_jobs.each do |job|
      job.cancel()
    end
  end

  def test_preview_and_events
    job = @service.jobs.create(QUERY, JOB_ARGS)
    assert_eventually_true() { job.is_done?() }
    assert_true(Integer(job['eventCount']) <= 3)

    preview_stream = job.preview()
    preview_results = ResultsReader.new(preview_stream)
    assert_false(preview_results.is_preview?)
    preview_array = preview_results.to_a()

    events_stream = job.events()
    events_results = ResultsReader.new(events_stream)
    assert_false(events_results.is_preview?)
    events_array = events_results.to_a()

    results_stream = job.results()
    results_results = ResultsReader.new(results_stream)
    assert_false(results_results.is_preview?)
    results_array = results_results.to_a()

    assert_equal(events_array, preview_array)
    assert_equal(results_array, preview_array)

    job.cancel()
  end

  def test_timeline
    original_xml_library = $splunk_xml_library
    job = @service.jobs.create(QUERY, JOB_ARGS)
    assert_eventually_true() { job.is_done?() }

    begin
      Splunk::require_xml_library(:rexml)
      timeline = job.timeline()
      assert_true(timeline.is_a?(Array))

      Splunk::require_xml_library(:nokogiri)
      timeline = job.timeline()
      assert_true(timeline.is_a?(Array))
    ensure
      # Have to reset the XML library or test_resultsreader gets unhappy.
      Splunk::require_xml_library(original_xml_library)
      job.cancel()
    end
  end

  def test_enable_preview
    begin
      install_app_from_collection("sleep_command")
      job = @service.jobs.create("search index=_internal | sleep 2 | join [sleep 2]")
      while !job.is_ready?()
        sleep(0.1)
      end
      assert_equal("0", job["isPreviewEnabled"])
      job.enable_preview()
      assert_eventually_true(1000) do
        job.refresh()
        fail("Job finished before preview enabled") if job.is_done?()
        job["isPreviewEnabled"] == "1"
      end
    ensure
      job.cancel()
      assert_eventually_true do
        !@service.jobs.contains?(job.sid)
      end
      # We have to wait for jobs to be properly killed or we can't delete
      # the sleep_command app in teardown on Windows.
      sleep(4)
    end
  end
end

class LongJobTestCase < JobsTestCase
  def setup
    super

    install_app_from_collection("sleep_command")
    @job = @service.jobs.create("search index=_internal | sleep 20")
    while !@job.is_ready?()
      sleep(0.1)
    end
  end

  def teardown
    if @job
      @job.cancel()
      assert_eventually_true(50) do
        !@service.jobs.has_key?(@job.sid)
      end
    end

    super
  end

  def test_setttl
    old_ttl = Integer(@job["ttl"])
    new_ttl = old_ttl + 1000

    @job.set_ttl(new_ttl)
    assert_eventually_true() do
      @job.refresh()
      ttl = Integer(@job["ttl"])
      ttl <= new_ttl && ttl > old_ttl
    end
  end

  def test_touch
    i = 2
    while i < 20
      sleep(i)
      old_ttl = Integer(@job.refresh()["ttl"])
      @job.touch()
      new_ttl = Integer(@job.refresh()["ttl"])
      if new_ttl > old_ttl
        break
      else
        i += 1
      end
    end
    assert_true(new_ttl > old_ttl)
  end
end

class RealTimeJobTestCase < JobsTestCase
  def setup
    super
    query = "search index=_internal"
    @job = @service.jobs.create(query,
                                :earliest_time => "rt-1d",
                                :latest_time => "rt",
                                :priority => 5)
    while !@job.is_ready?
      sleep(0.2)
    end
  end

  def teardown
    if @job
      @job.cancel()
      assert_eventually_true() do
        !@service.jobs.has_key?(@job.sid)
      end
    end

    super
  end

  def test_set_priority
    assert_equal("5", @job["priority"])
    sleep(1)
    new_priority = 3
    @job.set_priority(new_priority)
    assert_eventually_true(50) do
      @job.refresh()
      fail("Job finished before priority was set.") if @job.is_done?()
      @job["priority"] == "3"
    end
  end

  def test_get_preview
    assert_equal("1", @job["isPreviewEnabled"])
    assert_eventually_true do
      response = @job.preview()
      results = Splunk::ResultsReader.new(response)
      results.is_preview?
    end
  end

  def test_pause_unpause_finalize
    assert_equal("0", @job["isPaused"])

    @job.pause()
    assert_eventually_true() { @job.refresh()["isPaused"] == "1" }

    @job.unpause()
    assert_eventually_true() { @job.refresh()["isPaused"] == "0" }

    assert_equal("0", @job["isFinalized"])

    @job.finalize()
    assert_eventually_true() { @job.refresh()["isFinalized"] == "1" }
  end

  def test_searchlog
    log_stream = @job.searchlog
    assert_false(log_stream.empty?)
  end
end