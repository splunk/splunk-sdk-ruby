require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class TestCollection < TestCaseWithSplunkConnection
  def teardown
    c = Collection.new(@service, ["saved", "searches"])
    c.delete_if() { |e| e.name.start_with?("delete-me") }
    super
  end

  def test_constructor
    resource = [temporary_name(), temporary_name()]
    c = Collection.new(@service, resource)
    assert_equal(@service, c.service)
    assert_equal(resource, c.resource)
    assert_equal(Entity, c.entity_class)
  end

  def test_constructor_with_entity_class
    resource = [temporary_name(), temporary_name()]
    c = Collection.new(@service, resource, TestCollection)
    assert_equal(@service, c.service)
    assert_equal(resource, c.resource)
    assert_equal(TestCollection, c.entity_class)
  end

  def test_each_without_pagination
    n_entities = 0
    @service.apps.each(:count => 5) do |entity|
      assert_true(entity.is_a?(Entity))
      n_entities += 1
    end
    assert_true(n_entities <= 5)
  end

  def test_each_with_offset_and_count
    entities = []
    @service.apps.each(:count => 5) do |entity|
      entities << entity.name
    end

    entities_with_offset = []
    @service.apps.each(:count => entities.length-1, :offset => 1) do |entity|
      entities_with_offset << entity.name
    end

    assert_equal(entities[1..4], entities_with_offset)
  end

  def test_each_with_pagination
    total = 5 + rand(15)
    page_size = 1 + rand(3)

    entities = []
    @service.apps.each(:count => total) do |entity|
      entities << entity.name
    end

    entities_with_pagination = []
    @service.apps.each(:count => total, :page_size => page_size) do |entity|
      entities_with_pagination << entity.name
    end

    assert_equal(entities, entities_with_pagination)
  end

  def test_has_key
    c = @service.apps
    @service.apps.each(:count => 3) do |entity|
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

    c = Collection.new(@service, ["saved", "searches"])

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

    c = Collection.new(@service, ["saved", "searches"])

    c.create(search_name, :search => search)
    assert_true(c.has_key?(search_name))

    assert_raises(SplunkHTTPError) { c.create(search_name, :search => search) }

    c.delete(search_name)
    assert_false(c.has_key?(search_name))
  end

  def test_name_collisions
    search_name = temporary_name()
    search = "search * | head 5"

    saved_searches = Collection.new(@service, ["saved", "searches"])
    ss1 = saved_searches.create(search_name,
                                :search => search,
                                :namespace => Splunk::namespace(:sharing => "app",
                                                                :app => "search"))
    ss2 = saved_searches.create(search_name, :search => search,
                                :namespace => Splunk::namespace(:sharing => "user",
                                                                :app => "search",
                                                                :owner => "admin"))

    wildcard_service_args = @splunkrc.clone()
    wildcard_service_args[:namespace] = Splunk::namespace(:sharing => "user",
                                                          :owner => "-",
                                                          :app => "-")
    wildcard_service = Context.new(wildcard_service_args).login()

    wildcard_saved_searches =
        Collection.new(wildcard_service, ["saved", "searches"])
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
                     Splunk::namespace(:sharing => "app",
                                       :app => "search")).name)
    assert_equal(search_name,
                 wildcard_saved_searches.fetch(
                     search_name,
                     Splunk::namespace(:sharing => "user",
                                       :app => "search",
                                       :owner => "admin")).name)

    assert_raises(Splunk::AmbiguousEntityReference) do
      wildcard_saved_searches.delete(search_name)
    end

    # The order here is important. The app/search namespace
    # will delete both of the saved searches; user/search/admin
    # will only delete that particular one.
    wildcard_saved_searches.delete(search_name,
                                   namespace=Splunk::namespace(:sharing => "user",
                                                               :app => "search",
                                                               :owner => "admin"))
    assert_true(wildcard_saved_searches.has_key?(search_name))
    wildcard_saved_searches.delete(search_name,
                                   namespace=Splunk::namespace(:sharing => "app", :app => "search"))

    assert_false(wildcard_saved_searches.has_key?(search_name))
  end

  def test_values
    es = @service.apps.values(:count => 3)
    assert_true(es.length <= 3)
    es.each do |entity|
      assert_true(entity.is_a?(Entity))
    end
  end

  def test_each_equivales_values
    assert_equal(
        @service.apps.each().to_a().map() { |e| e.name },
        @service.apps.values.map() { |e| e.name }
    )
  end

  def test_length
    c = @service.apps
    assert_equal(c.values().length(), c.length())
    assert_equal(c.values().length(), c.size())
  end


  def test_select
    a = @service.apps.select() { |e| e.name == "search" }.to_a
    assert_equal(1, a.length)
    assert_equal("search", a[0].name)
  end

  def test_reject
    a = @service.apps.reject() { |e| e.name != "search" }.to_a
    assert_equal(1, a.length)
    assert_equal("search", a[0].name)
  end

  def test_fetch_nonexistant
    assert_nil(@service.apps.fetch("this does not exist"))
  end

  def test_assoc
    name, entity = @service.apps.assoc("search")
    assert_equal("search", name)
    assert_equal("search", entity.name)

    assert_nil(@service.apps.assoc("this does not exist"))
  end

  def test_keys
    keys = @service.apps.keys()
    assert_equal(@service.apps.values().map() { |e| e.name },
                 keys)
  end

  def test_each_key
    assert_equal(@service.apps.keys(), @service.apps.each_key.to_a)
  end

  def test_each_pair
    keys = []
    @service.apps.each_pair do |key, value|
      assert_equal(key, value.name)
      keys << key
    end
    assert_equal(@service.apps.keys(), keys)
  end

  def test_each_value
    keys = []
    @service.apps.each_value do |value|
      keys << value.name
    end
    assert_equal(@service.apps.keys(), keys)
  end

  def test_empty
    assert_false(@service.apps.empty?)
  end

  def test_delete_if
    c = Collection.new(@service, ["saved", "searches"])

    c.create(temporary_name(), :search => "search *")
    c.create(temporary_name(), :search => "search *")
    c.create(temporary_name(), :search => "search *")
    assert_equal(
        3,
        c.select() { |e| e.name.start_with?("delete-me") }.to_a.length()
    )

    c.delete_if() { |e| e.name.start_with?("delete-me") }

    assert_equal(
        0,
        c.select() { |e| e.name.start_with?("delete-me") }.to_a.length()
    )
  end

end