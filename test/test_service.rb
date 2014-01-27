require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class ServiceTestCase < TestCaseWithSplunkConnection
  def test_connect
    service = Splunk::connect(@splunkrc)
    assert_true(service.apps.length() > 0)
  end

  def test_loggers
    assert_false(@service.loggers.empty?)
    assert_equal(@service.loggers.length, @service.loggers.values.length)
  end

  def test_settings
    assert_not_nil(@service.settings.fetch("SPLUNK_HOME"))
  end

  def test_info
    keys = [
        "build", "cpu_arch", "guid", "isFree", "isTrial", "licenseKeys",
        "licenseSignature", "licenseState", "master_guid", "mode",
        "os_build", "os_name", "os_version", "serverName", "version" ]
    @service.info.keys {|key| assert(key.include? keys)}
  end

  def test_info_with_namespace
    service_args = @splunkrc.clone()
    custom_namespace = Splunk::namespace(:sharing => "user",
                                         :app => "search",
                                         :owner => service_args[:username])
    service_args[:namespace] = custom_namespace
    service = Splunk::connect(service_args)
    assert_equal(custom_namespace, service.namespace)
    keys = [
        "build", "cpu_arch", "guid", "isFree", "isTrial", "licenseKeys",
        "licenseSignature", "licenseState", "master_guid", "mode",
        "os_build", "os_name", "os_version", "serverName", "version" ]
    service.info.keys {|key| assert(key.include? keys)}
  end

  def test_capabilities
    expected = [
        "admin_all_objects", "change_authentication",
        "change_own_password", "delete_by_keyword",
        "edit_deployment_client", "edit_deployment_server",
        "edit_dist_peer", "edit_forwarders", "edit_httpauths",
        "edit_input_defaults", "edit_monitor", "edit_roles",
        "edit_scripted", "edit_search_server", "edit_server",
        "edit_splunktcp", "edit_splunktcp_ssl", "edit_tcp",
        "edit_udp", "edit_user", "edit_web_settings", "get_metadata",
        "get_typeahead", "indexes_edit", "license_edit", "license_tab",
        "list_deployment_client", "list_forwarders", "list_httpauths",
        "list_inputs", "request_remote_tok", "rest_apps_management",
        "rest_apps_view", "rest_properties_get", "rest_properties_set",
        "restart_splunkd", "rtsearch", "schedule_search", "search",
        "use_file_operator" ]
    capabilities = @service.capabilities
    expected.each do |item|
      assert(capabilities.include?(item))
    end
    end
end