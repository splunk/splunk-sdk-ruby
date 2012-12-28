require_relative 'test_helper'
require 'splunk-sdk-ruby/ordered_multimap'

include Splunk

class OrderdMultimapTestCase < Test::Unit::TestCase
  def test_create_with_new
    m = OrderedMultiMap.new({1=>2, 3=>4})
    assert_equal([2], m[1])
    assert_equal([4], m[3])
    assert_equal([1,3], m.keys())
  end

  def test_create_with_braces
    m = OrderedMultiMap[1, 2, 3, 4, 1, 4]
    assert_equal([2, 4], m[1])
    assert_equal([4], m[3])
    assert_equal([1,3], m.keys())
  end

  def test_equality
    assert_equal(OrderedMultiMap[1,2,3,4],
                 OrderedMultiMap[1,2,3,4])
    assert_true(OrderedMultiMap[1,2,1,3,4,5] ==
                    OrderedMultiMap[1,2,1,3,4,5])
    assert_false(OrderedMultiMap[1,3,1,2,4,5] ==
                     OrderedMultiMap[1,2,1,3,4,5])
  end

  def test_fetch
    m = OrderedMultiMap[1,2,3,4,1,16,1,12]
    assert_equal([2,16,12], m[1])
    assert_equal([2,16,12], m.fetch(1))
    assert_equal([4], m[3])
    assert_equal([4], m.fetch(3))
  end

  def test_fetch_with_default
    m = OrderedMultiMap[]
    assert_equal(5, m.fetch(:a, 5))
    assert_nil(m.fetch(:a))
  end

  def test_delete
    m = OrderedMultiMap[1, 2, 1, 3, 4, 5]
    assert_equal([2, 3], m[1])
    assert_equal([2, 3], m.delete(1))
    assert_equal(nil, m[1])
  end

  def test_each
    m = OrderedMultiMap[1, 2, 1, 3, 4, 5]
    i = 0
    keys = [1,1,4]
    vals = [2,3,5]
    m.each() do |key, value|
      assert_equal(keys[i], key)
      assert_equal(vals[i], value)
      i += 1
    end
    assert_equal(3, i)
  end

  def test_empty
    assert_false(OrderedMultiMap[1, 2].empty?)
    assert_true(OrderedMultiMap[].empty?)
  end

  def test_store
    m = OrderedMultiMap[]
    assert_true(m.empty?)
    m[1] = 2
    assert_equal([2], m[1])
    m[1] = :boris
    assert_equal([2, :boris], m[1])
    m.store(1, :quinoa)
    assert_equal([2, :boris, :quinoa], m.fetch(1))
  end

  def test_assoc
    assert_nil(OrderedMultiMap[].assoc(:boris))
    m = OrderedMultiMap[:a, 12, :a, 15, :b, 6]
    assert_equal([:a, [12,15]], m.assoc(:a))
  end

  def test_clear
    m = OrderedMultiMap[:a, 12]
    assert_false(m.empty?)
    m.clear()
    assert_true(m.empty?)
    assert_nil(m[:a])
  end

  def test_has_key?
    m = OrderedMultiMap[:a, 12, :b, 6, :a, 15]
    assert_true(m.has_key?(:a))
    assert_true(m.has_key?(:b))
    assert_false(m.has_key?(:boris))
  end

  def test_has_value?
    m = OrderedMultiMap[:a, 12, :b, 6, :a, 15]
    assert_true(m.has_value?(12))
    assert_true(m.has_value?(6))
    assert_true(m.has_value?(15))
    assert_false(m.has_value?(:a))
  end

  def test_to_s
    m = OrderedMultiMap[:a, 12, :a, 15, :b, 6]
    assert_equal(m, eval(m.to_s))
  end

  def test_invert
    m = OrderedMultiMap[:a, 12, :a, 15, :b, 15]
    assert_equal(OrderedMultiMap[12, :a, 15, :a, 15, :b],
                 m.invert())
  end
end