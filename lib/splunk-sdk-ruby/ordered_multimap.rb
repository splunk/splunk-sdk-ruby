module Splunk
  class OrderedMultiMap
    include Enumerable

    def initialize(template={})
      @contents = []

      template.each_entry() do |key, value|
        store(key, value)
      end
    end

    def self.[](*args)
      if args.length % 2 != 0
        raise ArgumentError("Must provide an even number of arguments.")
      end

      result = self.new()
      while args.length() > 0
        key = args.shift()
        value = args.shift()
        result.store(key, value)
      end
      result
    end

    def ==(other)
      to_a == other.to_a
    end

    def [](key)
      entry = @contents.assoc(key)
      if entry
        entry[1]
      else
        nil
      end
    end

    def store(key, value)
      @contents.each_with_index() do |entry, index|
        this_key, this_value = entry
        if key == this_key
          @contents[index][1] << value
          return
        end
      end
      @contents << [key, [value]]
    end

    def []=(key, value) store(key, value) end

    def assoc(key)
      @contents.assoc(key)
    end

    def clear()
      @contents = []
    end

    def delete(key)
      i = @contents.find_index() {|entry| entry[0] == key}
      @contents.delete_at(i)[1] || nil
    end

    def each(&block)
      @contents.each() do |entry|
        key, values = entry
        values.each() do |value|
          block.call(key, value)
        end
      end
    end

    def empty?()
      @contents.empty?()
    end

    def fetch(key, default=nil, &default_block)
      entry = @contents.assoc(key)
      if entry
        return entry[1]
      else
        return default
      end
    end

    def has_key?(key)
      !@contents.assoc(key).nil?
    end

    def include?(key) has_key?(key) end
    def key?(key) has_key?(key) end
    def member?(key) has_key?(key) end

    def has_value?(value)
      @contents.each() do |entry|
        this_key, these_values = entry
        if these_values.index(value)
          return true
        end
      end
      return false
    end
    def value?(value) has_value?(value) end

    def hash()
      @contents.hash()
    end

    def to_s()
      s = "OrderedMultiMap["
      s << map() {|key, value| "#{key.inspect}, #{value.inspect}"}.
          join(", ")
      s << "]"
      s
    end

    def inspect() to_s() end

    def invert()
      inverted = OrderedMultiMap.new()
      each() do |key, value|
        inverted[value] = key
      end
      inverted
    end

    def key()

    end

    def keys()
      @contents.map() {|e| e[0]}
    end

    def length()

    end

    def merge(other_hash)

    end

    def to_a() @contents end
  end
end