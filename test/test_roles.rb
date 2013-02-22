require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class RoleTestCase < TestCaseWithSplunkConnection
  def teardown
    @service.roles.each do |role|
      if role.name.start_with?("delete-me")
        @service.roles.delete(role.name)
      end
    end

    super
  end

  ##
  # Create a role and make sure the values we created it with actually
  # appear, and that the role appears in the collection. Then delete it and
  # make sure it vanishes from the collection.
  #
  def test_create_and_delete
    name = temporary_name()
    role = @service.roles.create(name)
    assert_true(@service.roles.has_key?(name))
    assert_equal(name, role.name)

    @service.roles.delete(name)
    assert_false(@service.roles.has_key?(name))
  end

  ##
  # Make sure that the roles collection normalizes all names to lowercase,
  # since role names are case insensitive.
  #
  def test_case_insensitive
    name = temporary_name() + "UPCASE"
    user = @service.roles.create(name)
    assert_true(@service.roles.has_key?(name.downcase()))
  end
end