require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class TestCollection < SplunkTestCase
  def teardown
    c = Collection.new(@context, ["saved", "searches"])
    c.delete_if() {|e| e.name.start_with?("delete-me")}
    super
  end

  def test_constructor
    resource = [temporary_name(), temporary_name()]
    c = Collection.new(@context, resource)
    assert_equal(@context, c.service)
    assert_equal(resource, c.resource)
    assert_equal(Entity, c.entity_class)
  end

  def test_constructor_with_entity_class
    resource = [temporary_name(), temporary_name()]
    c = Collection.new(@context, resource, TestCollection)
    assert_equal(@context, c.service)
    assert_equal(resource, c.resource)
    assert_equal(TestCollection, c.entity_class)
  end

  def test_each_without_pagination
    c = Collection.new(@context, ["apps", "local"])
    n_entities = 0
    c.each(:count=>5) do |entity|
      assert_true(entity.is_a?(Entity))
      n_entities += 1
    end
    assert_true(n_entities <= 5)
  end

  def test_each_with_offset_and_count
    c = Collection.new(@context, ["apps", "local"])

    entities = []
    c.each(:count => 5) do |entity|
      entities << entity.name
    end

    entities_with_offset = []
    c.each(:count => entities.length-1, :offset => 1) do |entity|
      entities_with_offset << entity.name
    end

    assert_equal(entities[1..4], entities_with_offset)
  end

  def test_each_with_pagination
    c = Collection.new(@context, ["apps", "local"])

    total = 5 + rand(15)
    page_size = 1 + rand(3)

    entities = []
    c.each(:count => total) do |entity|
      entities << entity.name
    end

    entities_with_pagination = []
    c.each(:count => total, :page_size => page_size) do |entity|
      entities_with_pagination << entity.name
    end

    assert_equal(entities, entities_with_pagination)
  end

  def test_has_key
    c = Collection.new(@context, ["apps", "local"])
    c.each(:count => 3) do |entity|
      assert_true(c.has_key?(entity.name))
      assert_true(c.contains?(entity.name))
      assert_true(c.include?(entity.name))
      assert_true(c.key?(entity.name))
      assert_true(c.member?(entity.name))
    end

    name = "nonexistant saved search"
    assert_false(c.has_key?(name))
    assert_false(c.contains?(name))
    assert_false(c.include?(name))
    assert_false(c.key?(name))
    assert_false(c.member?(name))
  end

  def test_create_and_delete
    search_name = temporary_name()
    search = "search index=_internal | head 10"

    c = Collection.new(@context, ["saved", "searches"])

    c.create(search_name, :search => search)
    assert_true(c.has_key?(search_name))

    assert_equal(search_name,
                 c.fetch(search_name).name)
    assert_equal(search_name,
                 c[search_name].name)

    c.delete(search_name)
    assert_false(c.has_key?(search_name))
  end

  def test_create_twice
    search_name = temporary_name()
    search = "search index=_internal | head 10"

    c = Collection.new(@context, ["saved", "searches"])

    c.create(search_name, :search => search)
    assert_true(c.has_key?(search_name))

    assert_raises(SplunkHTTPError) {c.create(search_name, :search => search)}

    c.delete(search_name)
    assert_false(c.has_key?(search_name))
  end

  def test_name_collisions
    search_name = temporary_name()
    search = "search * | head 5"

    saved_searches = Collection.new(@context, ["saved", "searches"])
    ss1 = saved_searches.create(search_name, :search => search,
                                :namespace => namespace("app", "search"))
    ss2 = saved_searches.create(search_name, :search => search,
                                :namespace => namespace("user", "search", "admin"))

    wildcard_context_args = @splunkrc.clone()
    wildcard_context_args[:namespace] = namespace("user", "-", "-")
    wildcard_context = Context.new(wildcard_context_args).login()

    wildcard_saved_searches =
        Collection.new(wildcard_context, ["saved", "searches"])
    assert_true(wildcard_saved_searches.has_key?(search_name))

    assert_raises(Splunk::AmbiguousEntityReference) do
      wildcard_saved_searches.fetch(search_name)
    end

    assert_raises(Splunk::AmbiguousEntityReference) do
      wildcard_saved_searches[search_name]
    end

    assert_equal(search_name,
                 wildcard_saved_searches.fetch(
                     search_name,
                     namespace("app", "search")).name)
    assert_equal(search_name,
                 wildcard_saved_searches.fetch(
                     search_name,
                     namespace("user", "search", "admin")).name)

    assert_raises(Splunk::AmbiguousEntityReference) do
      wildcard_saved_searches.delete(search_name)
    end

    # The order here is important. The app/search namespace
    # will delete both of the saved searches; user/search/admin
    # will only delete that particular one.
    wildcard_saved_searches.delete(search_name,
      namespace=namespace("user", "search", "admin"))
    assert_true(wildcard_saved_searches.has_key?(search_name))
    wildcard_saved_searches.delete(search_name,
      namespace=namespace("app", "search"))

    assert_false(wildcard_saved_searches.has_key?(search_name))
  end

  def test_values
    c = Collection.new(@context, ["apps", "local"])

    es = c.values(:count => 3)
    assert_true(es.length <= 3)
    es.each do |entity|
      assert_true(entity.is_a?(Entity))
    end
  end

  def test_each_equivales_values
    c = Collection.new(@context, ["apps", "local"])

    assert_equal(
        c.each().to_a().map() {|e| e.name},
        c.values.map() {|e| e.name}
    )
  end

  def test_length
    c = Collection.new(@context, ["apps", "local"])

    assert_equal(c.values().length(), c.length())
    assert_equal(c.values().length(), c.size())
  end


  def test_select
    c = Collection.new(@context, ["apps", "local"])

    a = c.select() {|e| e.name == "search"}.to_a
    assert_equal(1, a.length)
    assert_equal("search", a[0].name)
  end

  def test_reject
    c = Collection.new(@context, ["apps", "local"])
    a = c.reject() {|e| e.name != "search"}.to_a
    assert_equal(1, a.length)
    assert_equal("search", a[0].name)
  end

  def test_fetch_nonexistant
    c = Collection.new(@context, ["apps", "local"])
    assert_nil(c.fetch("this does not exist"))
  end

  def test_assoc
    c = Collection.new(@context, ["apps", "local"])
    name, entity = c.assoc("search")
    assert_equal("search", name)
    assert_equal("search", entity.name)

    assert_nil(c.assoc("this does not exist"))
  end

  def test_keys
    c = Collection.new(@context, ["apps", "local"])
    keys = c.keys()
    assert_equal(c.values().map(){|e| e.name},
                 keys)
  end

  def test_each_key
    c = Collection.new(@context, ["apps", "local"])

    keys = []
    c.each_key do |key|
      keys << key
    end
    assert_equal(c.keys(), keys)
  end

  def test_each_pair
    c = Collection.new(@context, ["apps", "local"])

    keys = []
    c.each_pair do |key, value|
      assert_equal(key, value.name)
      keys << key
    end
    assert_equal(c.keys(), keys)
  end

  def test_each_value
    c = Collection.new(@context, ["apps", "local"])

    keys = []
    c.each_value do |value|
      keys << value.name
    end
    assert_equal(c.keys(), keys)
  end

  def test_empty
    c = Collection.new(@context, ["apps", "local"])

    assert_false(c.empty?)
  end

  def test_delete_if
    c = Collection.new(@context, ["saved", "searches"])

    c.create(temporary_name(), :search => "search *")
    c.create(temporary_name(), :search => "search *")
    c.create(temporary_name(), :search => "search *")
    assert_equal(
        3,
        c.select() {|e| e.name.start_with?("delete-me")}.to_a.length()
    )

    c.delete_if() {|e| e.name.start_with?("delete-me")}

    assert_equal(
        0,
        c.select() {|e| e.name.start_with?("delete-me")}.to_a.length()
    )
  end

end