require_relative 'test_helper'
require 'splunk-sdk-ruby/namespace'

include Splunk

class TestNamespaces < Test::Unit::TestCase
  def test_equality
    assert_equal(namespace("global"), namespace("global"))
    assert_equal(namespace("system"), namespace("system"))
    assert_equal(namespace("default"), namespace("default"))
    assert_equal(namespace("user", application="search", user="boris"),
                 namespace("user", application="search", user="boris"))
    assert_equal(namespace("app", application="search"),
                 namespace("app", application="search"))
  end

  def test_inequality
    assert_not_equal(namespace("global"), namespace("system"))
    assert_not_equal(namespace("app", "search"),
                     namespace("app", "gettingstarted"))
    assert_not_equal(namespace("user", application="search", user="boris"),
                     namespace("app", application="search"))
    assert_not_equal(namespace("default"), namespace("system"))
    assert_not_equal(namespace("user", application="search", user="boris"),
                     namespace("user", application="search", user="hilda"))
  end

  def test_types
    assert_true(namespace("global").is_a?(GlobalNamespace))
    assert_true(namespace("global").is_a?(Namespace))

    assert_true(namespace("system").is_a?(SystemNamespace))
    assert_true(namespace("system").is_a?(Namespace))

    assert_true(namespace("app", "search").is_a?(ApplicationNamespace))
    assert_true(namespace("app", "search").is_a?(Namespace))

    assert_true(namespace("user", "search", "boris").is_a?(UserNamespace))
    assert_true(namespace("user", "search", "boris").is_a?(Namespace))

    assert_true(namespace("default").is_a?(DefaultNamespace))
    assert_true(namespace("default").is_a?(Namespace))

    assert_true(namespace().is_a?(DefaultNamespace))
    assert_true(namespace().is_a?(Namespace))
  end

  def test_throws_without_enough_information
    assert_raise ArgumentError do
      namespace("user")
    end

    assert_raise ArgumentError do
      namespace("user", "boris")
    end

    assert_raise ArgumentError do
      namespace("app")
    end
  end

  def test_propriety
    assert_true(namespace("global").is_proper?)
    assert_true(namespace("system").is_proper?)
    assert_false(namespace("default").is_proper?)
    assert_false(namespace().is_proper?)
    assert_true(namespace("app", "search").is_proper?)
    assert_false(namespace("app", "-").is_proper?)
    assert_true(namespace("user", "search", "boris").is_proper?)
    assert_false(namespace("user", "-", "boris").is_proper?)
    assert_false(namespace("user", "search", "-").is_proper?)
    assert_false(namespace("user", "-", "-").is_proper?)
  end

  def test_path_segments
    assert_equal(["services"], namespace().to_path_fragment())
    assert_equal(["services"], namespace("default").to_path_fragment())
    assert_equal(["servicesNS","nobody","system"],
                 namespace("global").to_path_fragment)
    assert_equal(["servicesNS", "nobody", "system"],
                 namespace("system").to_path_fragment)
    assert_equal(["servicesNS", "nobody", "search"],
                 namespace("app",
                           application="search").to_path_fragment)
    assert_equal(["servicesNS", "nobody", "-"],
                 namespace("app",
                           application="-").to_path_fragment)
    assert_equal(["servicesNS", "boris", "search"],
                 namespace("user", application="search",
                           user="boris").to_path_fragment)
  end

  def test_eai_acl_to_namespace
    data = {
        namespace("app", "system") => {
            "app" => "system",
            "can_change_perms" => "1",
            "can_list" => "1",
            "can_share_app" => "1",
            "can_share_global" => "1",
            "can_share_user" => "0",
            "can_write" => "1",
            "modifiable" => "1",
            "owner" => "nobody",
            "perms" => {
                "read" => ["*"],
                "write" => ["power"]
            },
            "removable" => "0",
            "sharing" => "app"
        },
        namespace("global") => {
            "perms" => {
                "read" => ["admin"],
                "write" => ["admin"],
            },
            "owner" => "admin",
            "modifiable" => "1",
            "sharing" => "global",
            "app" => "search",
            "can_write" => "1"
        },
        namespace("default") => {
            "app" => "",
            "can_change_perms" => "1",
            "can_list" => "1",
            "can_share_app" => "1",
            "can_share_global" => "1",
            "can_share_user" => "0",
            "can_write" => "1",
            "modifiable" => "1",
            "owner" => "system",
            "perms" => {
                "read" => ["*"],
                "write" => ["power"]
            },
            "removable" => "0",
            "sharing" => "app",
        }
    }
    data.each_entry do |expected_namespace, eai_acl|
      found_namespace = eai_acl_to_namespace(eai_acl)
      assert_equal(expected_namespace, found_namespace)
    end
  end
end



