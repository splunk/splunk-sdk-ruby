require_relative "test_helper"
require "splunk-sdk-ruby"

include Splunk

class TestRestarts < SplunkTestCase
  def test_restart_with_long_timeout
    context = Context.new(@splunkrc).login()
    context.restart(1000)
    assert_logged_in(context)
  end

  def test_restart_with_short_timeout
    context = Context.new(@splunkrc).login()
    begin
      context.restart(0.1)
    rescue TimeoutError
      # Wait for it to come back up
      while !context.server_accepting_connections? ||
          context.server_requires_restart?
        sleep(0.3)
      end
      assert_logged_in(context)
    else
      fail("Somehow Splunk managed to restart in 100ms...")
    end
  end

  def test_restart_with_no_timeout
    context = Context.new(@splunkrc).login()
    context.restart()
    assert_not_logged_in(context)

    # Wait for it to come back up
    while !context.server_accepting_connections? ||
        context.server_requires_restart?
      sleep(0.3)
    end
    assert_logged_in(context)
  end
end
