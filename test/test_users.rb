require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class UserTestCase < TestCaseWithSplunkConnection
  def teardown
    @service.users.each do |user|
      if user.name.start_with?("delete-me")
        @service.users.delete(user.name)
      end
    end

    super
  end

  def test_create_and_delete
    name = temporary_name()
    user = @service.users.create(name, :password => "abc", :roles => ["power"])
    assert_true(@service.users.has_key?(name))
    assert_equal(name, user.name)
    assert_equal(["power"], user["roles"])

    @service.users.delete(name)
    assert_false(@service.users.has_key?(name))
  end

  def test_case_insensitive
    name = temporary_name() + "UPCASE"
    user = @service.users.create(name, :password => "abc", :roles => ["power"])
    assert_true(@service.users.has_key?(name.downcase()))
  end
end