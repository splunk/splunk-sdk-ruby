require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class MessagesTestCase < TestCaseWithSplunkConnection
  def test_message
    messages = @service.messages
    messages.create("sdk_message", :value => "Moose on the roof")
    assert_true(messages.has_key?("sdk_message"))
    message = messages.fetch("sdk_message")
    assert_equal("sdk_message", message.name)
    assert_equal("Moose on the roof", message.value)
    messages.delete("sdk_message")
    assert_false(messages.has_key?("sdk_message"))
  end
end