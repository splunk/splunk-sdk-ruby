require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class EntityTestCase < SplunkTestCase
  def setup
    super
    @app_args = {
        "author" => "Harry Belten",
        "label" => "A random app",
        "description" => "Sumer is icumen in",
    }
    @entity = @service.apps.create(temporary_name(), @app_args)
  end

  def teardown
    @entity.delete()
    clear_restart_message(@service)
    super
  end

  def test_fetch
    @app_args.each() do |key, value|
      assert_equal(value, @entity[key])
      assert_equal(value, @entity.fetch(key))
    end
  end

  def test_fetch_with_default
    assert_equal("boris", @entity.fetch("nonexistant key", "boris"))
  end

  def test_update_and_refresh
    @entity.update("label" => "This is a test")
    assert_equal(@app_args["label"], @entity["label"])
    @entity.refresh()
    assert_equal("This is a test", @entity["label"])

    @entity["label"] = "Oh the vogonity!"
    assert_equal("This is a test", @entity["label"])
    @entity.refresh()
    assert_equal("Oh the vogonity!", @entity["label"])
  end

  def test_read
    state = @entity.read()
    assert_false(state.empty?)
    state.each() do |key, value|
      assert_equal(value, @entity[key])
    end
    state.each() do |key, value|
      state[key] = "boris"
      assert_not_equal("boris", value)
      assert_equal(value, @entity[key])
    end
  end

  def test_state_with_field_list
    state = @entity.read("label", "description")
    assert_false(state.empty?)
    state.each() do |key, value|
      assert_equal(value, @entity[key])
    end
    state.each() do |key, value|
      state[key] = "boris"
      assert_not_equal("boris", value)
      assert_equal(value, @entity[key])
    end

    assert_equal(@entity.read("label", "description"),
                 @entity.read(["label", "description"]))
  end

  def test_disable_enable
    # We have to refresh first, because apps on some versions of Splunk
    # do not have all their keys (including "disabled") when first created.
    @entity.refresh()

    assert_equal('0', @entity["disabled"])

    @entity.disable()
    @entity.refresh()
    assert_equal('1', @entity["disabled"])

    @entity.enable()
    @entity.refresh()
    assert_equal('0', @entity["disabled"])
  end

end