require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class ModularInputKindsTestCase < TestCaseWithSplunkConnection
  def setup
    super

    omit_if(@service.splunk_version[0] < 5)
    if !has_app_collection?(@service)
      fail("Install the SDK app collection to test modular input kinds.")
    end
    install_app_from_collection("modular-inputs")
  end

  def test_list_arguments
    test1 = @service.modular_input_kinds["test1"]
    expected_args = ["name", "resname", "key_id", "no_description",
                     "empty_description", "arg_required_on_edit",
                     "not_required_on_edit", "required_on_create",
                     "not_required_on_create", "number_field",
                     "string_field", "boolean_field"].sort()
    found_args = test1.arguments.keys().sort()
    assert_equal(expected_args, found_args)
  end
end