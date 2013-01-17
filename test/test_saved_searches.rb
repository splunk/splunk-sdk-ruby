require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class SavedSearchesTestCase < TestCaseWithSplunkConnection
  def teardown
    @service.saved_searches.each do |ss|
      if ss.name.start_with?("delete-me")
        ss.history.each() {|job| job.cancel()}
        @service.saved_searches.delete(ss.name)
      end
    end

    assert_eventually_true do
      @service.saved_searches.all?() {|ss| !ss.name.start_with?("delete-me")}
    end

    super
  end

  def check_saved_search(saved_search)
    expected_fields = ['alert.expires',
                       'alert.severity',
                       'alert.track',
                       'alert_type',
                       'dispatch.buckets',
                       'dispatch.lookups',
                       'dispatch.max_count',
                       'dispatch.max_time',
                       'dispatch.reduce_freq',
                       'dispatch.spawn_process',
                       'dispatch.time_format',
                       'dispatch.ttl',
                       'max_concurrent',
                       'realtime_schedule',
                       'restart_on_searchpeer_add',
                       'run_on_startup',
                       'search',
                       'action.email',
                       'action.populate_lookup',
                       'action.rss',
                       'action.script',
                       'action.summary_index']
    expected_fields.each do |f|
      saved_search[f]
    end

    is_scheduled = saved_search["is_scheduled"]
    assert_true(is_scheduled == '1' || is_scheduled == '0')
    is_visible = saved_search["is_visible"]
    assert_true(is_visible == '1' || is_visible == '0')
  end

  ##
  # Make sure we can create a saved search, it shows up in the collection,
  # and we can delete it.
  #
  def test_create_and_delete
    saved_search_name = temporary_name()
    @service.saved_searches.create(saved_search_name, :search => "search *")
    assert_eventually_true(3) do
      @service.saved_searches.has_key?(saved_search_name)
    end

    check_saved_search(@service.saved_searches[saved_search_name])

    @service.saved_searches.delete(saved_search_name)
    assert_eventually_true(3) do
      !@service.saved_searches.member?(saved_search_name)
    end
  end

  ##
  # In Splunk 4.x, update on saved searches has to have special behavior, since
  # Splunk will try to clear the search if you don't pass it (or will throw an
  # error if you don't pass it). So we make sure that update works and the
  # search is the same before and after.
  #
  def test_update
    saved_search_name = temporary_name()
    ss = @service.saved_searches.create(saved_search_name,
                                        :search => "search *")

    ss.update(:description => "boris")
    ss.refresh()
    assert_equal("boris", ss["description"])
    assert_equal("search *", ss["search"])
  end

  ##
  # In contrast to the previous test, make sure that we can set the search.
  # with update.
  #
  def test_update_search
    saved_search_name = temporary_name()
    ss = @service.saved_searches.create(saved_search_name,
                                        :search => "search *")

    ss.update(:description => "boris",
              :search => "search index=_internal *")
    ss.refresh()
    assert_equal("boris", ss["description"])
    assert_equal("search index=_internal *", ss["search"])
  end

  ##
  #
  def test_dispatch()
    saved_search_name = temporary_name()
    ss = @service.saved_searches.create(saved_search_name,
                                        :search => "search *")
    job = ss.dispatch()
    while !job.is_ready?()
      sleep(0.2)
    end
  end

end