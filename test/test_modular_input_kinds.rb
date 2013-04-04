require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class ModularInputKindsTestCase < TestCaseWithSplunkConnection
  def setup
    super

    omit_if(@service.splunk_version[0] < 5)
    if not has_test_data?(@service)
      fail("Install the SDK test data to test modular input kinds.")
    end
    install_app_from_collection("modular-inputs")
  end

  ##
  # Does the argument method on ModularInputKind return the expected keys
  # on a known modular input kind?
  #
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

  ##
  # Does each iterate properly? Are the headers of the modular inputs sane?
  #
  def test_list_modular_inputs_and_headers
    @service.modular_input_kinds.each do |mod_input|
      if mod_input.name == "test1"
        assert_equal('Test "Input" - 1', mod_input["title"])
        assert_equal("xml", mod_input["streaming_mode"])
      elsif mod_input.name == "test2"
        assert_equal("test2", mod_input["title"])
        assert_equal("simple", mod_input["streaming_mode"])
      end
    end
  end
end