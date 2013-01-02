require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class TestCollection < SplunkTestCase
  def test_constructor
    path = [temporary_name(), temporary_name()]
    c = Collection.new(@context, path)
    assert_equal(@context, c.service)
    assert_equal(path, c.path)
    assert_equal(Entity, c.entity_class)
  end

  def test_constructor_with_entity_class
    path = [temporary_name(), temporary_name()]
    c = Collection.new(@context, path, TestCollection)
    assert_equal(@context, c.service)
    assert_equal(path, c.path)
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

  def test_each_synonym_for_each_pair
    c = Collection.new(@context, ["apps", "local"])

    total = 5 + rand(15)
    page_size = 1 + rand(3)

    entities = []
    c.each(:count => total, :page_size => page_size) do |entity|
      entities << entity.name
    end

    entities_from_pair = []
    c.each_pair(:count => total, :page_size => page_size) do |entity|
      entities_from_pair << entity.name
    end

    assert_equal(entities, entities_from_pair)
  end
end