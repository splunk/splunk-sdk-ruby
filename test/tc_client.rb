require "test/unit"
require "ostruct"
require "splunk-sdk/client"

ADMIN_LOGIN = "admin"
ADMIN_PSW = "sk8free"
TEST_APP_NAME = "sdk-tests"

class TcClient < Test::Unit::TestCase
  def setup
    @service = Service.new(:username => ADMIN_LOGIN, :password => ADMIN_PSW)
  end

=begin

  def test_apps
    @service.apps.each do |app|
      app.read
    end

    if @service.apps.list.include?(TEST_APP_NAME)
      @service.apps.delete(TEST_APP_NAME)
    end
    assert(@service.apps.list.include?(TEST_APP_NAME) == false)

    @service.apps.create(TEST_APP_NAME)
    assert(@service.apps.list.include?(TEST_APP_NAME))

    test_app = @service.apps[TEST_APP_NAME]
    test_app['author'] = "Splunk"

    assert(test_app['author'] == "Splunk")

    @service.apps.delete(TEST_APP_NAME)
    assert(@service.apps.list.include?(TEST_APP_NAME) == false)
  end
=end

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

  def test_info
    @service.info.build
  end
end
