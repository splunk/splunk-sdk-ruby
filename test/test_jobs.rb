require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

QUERY = "search index=_internal | head 3"
JOB_ARGS = {:earliest_time => "-1m", :latest_time => "now",
            :status_buckets => 10}

class JobsTestCase < SplunkTestCase
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
    assert_eventually_true() {!jobs.has_key?(job.sid)}
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

  def test_oneshot_with_garbage_fails
    assert_raises(SplunkHTTPError) do
      @service.jobs.create_oneshot("abcwrawerafawf 'adfad'faw")
    end
  end

  def test_stream_with_garbage_fails
    assert_raises(SplunkHTTPError) do
      @service.jobs.create_stream("abavadfa;ejwfawfasdfadf wfw").to_a()
    end
  end

  def test_stream
    stream = @service.jobs.create_stream(QUERY)
    results = ResultsReader.new(stream).to_a()
    assert_equal(3, results.length())
  end

  def test_each_and_values
    jobs = Jobs.new(@service)

    (1..3).each() do |i|
      jobs.create("search index=_internal | head #{i}")
    end

    each_jobs = []
    jobs.each() do |job|
      assert_false(job.name.empty?)
      each_jobs << job.sid
    end

    assert_equal(each_jobs, jobs.values().map() {|j| j.sid})
  end

  def test_preview_and_events
    job = @service.jobs.create(QUERY, JOB_ARGS)
    assert_eventually_true() { job.is_done() }
    assert_true( Integer(job['eventCount']) <= 3 )

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
  end

  def test_timeline
    job = @service.jobs.create(QUERY, JOB_ARGS)
    assert_eventually_true() { job.is_done() }
    Splunk::require_xml_library(:rexml)
    timeline = job.timeline()
    assert_true(timeline.is_a?(Array))

    Splunk::require_xml_library(:nokogiri)
    timeline = job.timeline()
    assert_true(timeline.is_a?(Array))
  end
end

class JobWithDelayedDoneTestCase < JobsTestCase
  def setup
    super
    install_app_from_collection("sleep_command")
    query = "search index=_internal | sleep 1000"
    @job = @service.jobs.create(query,
                                :earliest_time => "-1m",
                                :latest_time => "now",
                                :priority => 5)

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

  def test_enable_preview
    assert_equal("0", @job["isPreviewEnabled"])
    @job.enable_preview()
    assert_eventually_true(100) do
      @job.refresh()
      fail("Job finished before preview enabled") if @job.is_done()
      @job["isPreviewEnabled"] == "1"
    end
  end

  def test_set_priority
    assert_equal("5", @job["priority"])

    new_priority = 3
    @job.set_priority(new_priority)
    assert_eventually_true(120) do
      @job.refresh()
      fail("Job finished before priority was set.") if @job.is_done()
      @job["priority"] == "3"
    end
  end

  def test_get_preview
    @job.enable_preview()
    response = @job.preview()
    results = Splunk::ResultsReader.new(response)
    assert_true(results.is_preview?)
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
    sleep(2)
    old_ttl = Integer(@job.refresh()["ttl"])
    @job.touch()
    new_ttl = Integer(@job.refresh()["ttl"])
    if new_ttl == old_ttl
      fail("Didn't wait long enough to make ttl change meaningful.")
    end
    assert_true(new_ttl > old_ttl)
  end

  def test_searchlog
    log_stream = @job.searchlog
    assert_false(log_stream.empty?)
  end
end