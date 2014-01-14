require_relative 'test_helper'
require 'splunk-sdk-ruby/namespace'

include Splunk

class TestNamespaces < Test::Unit::TestCase
  def test_incorrect_constructors
    assert_raises(ArgumentError) { Splunk::namespace(:sharing => "boris") }
    assert_raises(ArgumentError) { Splunk::namespace(:sharing => "app") }
    assert_raises(ArgumentError) { Splunk::namespace(:sharing => "user") }
    assert_raises(ArgumentError) { Splunk::namespace(:sharing => "user",
                                                     :app => "search") }
    assert_raises(ArgumentError) { Splunk::namespace() }
  end

  def test_equality
    assert_equal(Splunk::namespace(:sharing => "global"),
                 Splunk::namespace(:sharing => "global"))
    assert_equal(Splunk::namespace(:sharing => "system"),
                 Splunk::namespace(:sharing => "system"))
    assert_equal(Splunk::namespace(:sharing => "default"),
                 Splunk::namespace(:sharing => "default"))
    assert_equal(Splunk::namespace(:sharing => "user",
                                   :app => "search",
                                   :owner => "boris"),
                 Splunk::namespace(:sharing => "user",
                                   :app => "search",
                                   :owner => "boris"))
    assert_equal(Splunk::namespace(:sharing => "app",
                                   :app => "search"),
                 Splunk::namespace(:sharing => "app",
                                   :app => "search"))
  end

  def test_inequality
    assert_not_equal(Splunk::namespace(:sharing => "global"),
                     Splunk::namespace(:sharing => "system"))
    assert_not_equal(Splunk::namespace(:sharing => "app", :app => "search"),
                     Splunk::namespace(:sharing => "app", :app => "gettingstarted"))
    assert_not_equal(Splunk::namespace(:sharing => "user",
                                       :app => "search",
                                       :owner => "boris"),
                     Splunk::namespace(:sharing => "app",
                                       :app => "search"))
    assert_not_equal(Splunk::namespace(:sharing => "default"),
                     Splunk::namespace(:sharing => "system"))
    assert_not_equal(Splunk::namespace(:sharing => "user",
                                       :app => "search",
                                       :owner => "boris"),
                     Splunk::namespace(:sharing => "user",
                                       :app => "search",
                                       :owner => "hilda"))
  end

  def test_types
    assert_true(Splunk::namespace(:sharing => "global").is_a?(GlobalNamespace))
    assert_true(Splunk::namespace(:sharing => "global").is_a?(Namespace))

    assert_true(Splunk::namespace(:sharing => "system").is_a?(SystemNamespace))
    assert_true(Splunk::namespace(:sharing => "system").is_a?(Namespace))

    assert_true(Splunk::namespace(:sharing => "app",
                                  :app => "search").is_a?(AppNamespace))
    assert_true(Splunk::namespace(:sharing => "app",
                                  :app => "search").is_a?(Namespace))

    assert_true(Splunk::namespace(:sharing => "app",
                                  :app => "").is_a?(AppReferenceNamespace))
    assert_true(Splunk::namespace(:sharing => "app",
                                  :app => "").is_a?(Namespace))

    assert_true(Splunk::namespace(:sharing => "user",
                                  :app => "search",
                                  :owner => "boris").is_a?(UserNamespace))
    assert_true(Splunk::namespace(:sharing => "user",
                                  :app => "search",
                                  :owner => "boris").is_a?(Namespace))

    assert_true(Splunk::namespace(:sharing => "default").is_a?(DefaultNamespace))
    assert_true(Splunk::namespace(:sharing => "default").is_a?(Namespace))
  end

  def test_throws_without_enough_information
    assert_raise ArgumentError do
      Splunk::namespace(:sharing => "user")
    end

    assert_raise ArgumentError do
      Splunk::namespace(:sharing => "user", :app => "boris")
    end

    assert_raise ArgumentError do
      Splunk::namespace(:sharing => "app")
    end
  end

  def test_propriety
    assert_true(Splunk::namespace(:sharing => "global").is_exact?)
    assert_true(Splunk::namespace(:sharing => "system").is_exact?)
    assert_true(Splunk::namespace(:sharing => "default").is_exact?)
    assert_true(Splunk::namespace(:sharing => "app", :app => "search").is_exact?)
    assert_false(Splunk::namespace(:sharing => "app", :app => "-").is_exact?)
    assert_true(Splunk::namespace(:sharing => "app", :app => "").is_exact?)
    assert_true(Splunk::namespace(:sharing => "user", :app => "search",
                                  :owner => "boris").is_exact?)
    assert_false(Splunk::namespace(:sharing => "user", :app => "-",
                                   :owner => "boris").is_exact?)
    assert_false(Splunk::namespace(:sharing => "user", :app => "search",
                                   :owner => "-").is_exact?)
    assert_false(Splunk::namespace(:sharing => "user", :app => "-",
                                   :owner => "-").is_exact?)
  end

  def test_path_segments
    assert_equal(["services"], Splunk::namespace(:sharing => "default").to_path_fragment())
    assert_equal(["servicesNS", "nobody", "system"],
                 Splunk::namespace(:sharing => "global").to_path_fragment)
    assert_equal(["servicesNS", "nobody", "system"],
                 Splunk::namespace(:sharing => "system").to_path_fragment)
    assert_equal(["servicesNS", "nobody", "search/@!"],
                 Splunk::namespace(:sharing => "app", :app => "search/@!").to_path_fragment)
    assert_equal(["servicesNS", "nobody", "-"],
                 Splunk::namespace(:sharing => "app", :app => "-").to_path_fragment)
    assert_equal(["services"], Splunk::namespace(:sharing => "app",
                                                 :app => "").to_path_fragment)
    assert_equal(["servicesNS", "boris/@!", "search/@!"],
                 Splunk::namespace(:sharing => "user",
                                   :app => "search/@!",
                                   :owner => "boris/@!").to_path_fragment)
  end

  def test_eai_acl_to_namespace
    data = {
        Splunk::namespace(:sharing => "app", :app => "system") => {
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
        Splunk::namespace(:sharing => "global") => {
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
        Splunk::namespace(:sharing => "app", :app => "") => {
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
      found_namespace = Splunk::eai_acl_to_namespace(eai_acl)
      assert_equal(expected_namespace, found_namespace)
    end
  end
end



