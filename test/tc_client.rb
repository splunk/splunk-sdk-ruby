require "test/unit"
require "ostruct"
require "splunk-sdk/client"

ADMIN_LOGIN = "admin"
ADMIN_PSW = "sk8free"
TEST_APP_NAME = "sdk-tests"

class TcAloader < Test::Unit::TestCase
    def setup
        @service = Service.new(:username => ADMIN_LOGIN, :password => ADMIN_PSW)
    end

    def test_apps
        @service.apps.delete(TEST_APP_NAME) if @service.apps.list.include?(TEST_APP_NAME)
        assert(@service.apps.list.include?(TEST_APP_NAME) == false) 

        @service.apps.create(TEST_APP_NAME)
        assert(@service.apps.list.include?(TEST_APP_NAME))

        test_app = @service.apps[TEST_APP_NAME]
        test_app['author'] = "Splunk"

        @service.apps.delete(TEST_APP_NAME)
        assert(@service.apps.list.include?(TEST_APP_NAME) == false) 
    end
end
