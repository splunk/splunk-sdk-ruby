require_relative "test_helper"
require "splunk-sdk-ruby"

include Splunk

class TestRestarts < TestCaseWithSplunkConnection
  def test_restart_with_long_timeout
    service = Context.new(@splunkrc).login()
    begin
      service.restart(2000)
    rescue TimeoutError
      while !service.server_accepting_connections? ||
          service.server_requires_restart?
        sleep(0.3)
      end
    end

    assert_logged_in(service)
  end

  def test_restart_with_short_timeout
    service = Context.new(@splunkrc).login()
    begin
      service.restart(0.1)
    rescue TimeoutError
      # Wait for it to come back up
      while !service.server_accepting_connections? ||
          service.server_requires_restart?
        sleep(0.3)
      end
      assert_logged_in(service)
    else
      fail("Somehow Splunk managed to restart in 100ms...")
    end
  end

  def test_restart_with_no_timeout
    service = Context.new(@splunkrc).login()
    service.restart()
    assert_not_logged_in(service)

    # Wait for it to come back up
    while !service.server_accepting_connections? ||
        service.server_requires_restart?
      sleep(0.3)
    end
    assert_logged_in(service)
  end
end
