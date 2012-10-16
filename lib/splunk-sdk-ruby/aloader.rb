require 'rubygems'

require 'nokogiri'
require 'netrc'


# Some bitchin metaprogramming to allow "dot notation" reading from a Hash
class Hash
  def add_attrs
    self.each do |k, v|
      # Replace any embedded : with an _
      key = k.gsub(/@:-\./, '_')
      if v.is_a?(Hash)
        instance_variable_set("@#{key}", v.add_attrs)
      else
        instance_variable_set("@#{key}", v)
      end
      class << self; self; end.instance_eval do # do this on obj's metaclass
        attr_reader key.to_sym # add getter method for this ivar
      end
    end
  end

  def urlencode
    output = ''
    each do |k,v|
      output += '&' if !output.empty?
      output += URI.escape(
        k.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      output += '=' + URI.escape(
        v.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end
    output
  end
end

module Splunk
  XML_NS = 'http://dev.splunk.com/ns/rest'

  class AtomResponseLoader
  public

    def initialize(text, match=nil, namespaces=nil)
      raise ArgumentError, 'text is nil' if text.nil?
      text = text.strip
      raise ArgumentError, 'text size is 0' if text.size == 0
      @text = text
      @match = match
      @namespaces = namespaces
    end

    def load()
      doc = Nokogiri::XML(@text)

      # if the document is empty, bail
      return nil unless doc.root

      if @match.nil?
        items = [doc.root]
      elsif @namespaces.nil?
        items = doc.root.xpath(@match)
      else
        items = doc.root.xpath(@match, @namespaces)
      end

      return load_root(items[0]) if items.size == 1

      items.collect do |item|
        load_root(item)
      end
    end

    def self.load_text(text, match=nil, namespaces=nil)
      AtomResponseLoader.new(text, match, namespaces).load
    end

    def self.load_text_as_record(text, match=nil, namespaces=nil)
      result = AtomResponseLoader.new(text, match, namespaces).load
      if result.is_a?(Array)
        result.collect {|item| item.add_attrs }
      else
        result.add_attrs
      end
    end

    # Method to convert a dict to a 'dot notation' accessor object
    def self.record(hash)
      hash.add_attrs
    end

  private
    def load_root(node)
      return load_dict(node) if is_dict(node)
      return load_list(node) if is_list(node)
      k,v = load_elem(node)
      {k => v}
    end

    def load_elem(node)
      name = localname(node)
      attrs = load_attrs(node)
      value = load_value(node)
      return name,value if attrs.nil?
      return name,attrs if value.nil?

      if value.instance_of?(String)
        attrs['_text'] = value
        return name, attrs
      end

      attrs.each {|k,v| value[k] = v }
      [name, value]
    end

    def load_attrs(node)
      return nil if node.attributes.empty?
      attrs = {}
      node.attributes.each {|k,v| attrs[k] = v.value }
      attrs
    end

    def load_dict(node)
      value = {}
      node.element_children.each do |child|
        if is_key(child)
          name = child.attributes['name'].value
        else
          name = child.name
        end
        value[name] = load_value(child) if name
      end
      value
    end

    def load_list(node)
      node.element_children.collect {|child| load_value(child) }
    end

    def load_value(node)
      value = {}
      node.children.each do |child|
        if child.text?
          text = child.text
          return nil if text.nil?
          text.strip!
          next if text.empty?
          # This would be a malformed doc
          next if node.children.size > 1
          return text
        elsif child.element?
          return load_dict(child) if is_dict(child)
          return load_list(child) if is_list(child)
          name, item = load_elem(child)
          if value.has_key?(name)
            value[name] = [value[name]] unless value[name].instance_of?(Array)
            value[name] << item
          else
            value[name] = item
          end
        end
      end
      value.empty? ? nil : value
    end

    def is_dict(node)
      is_special(node, 'dict')
    end

    def is_list(node)
      is_special(node, 'list')
    end

    def is_item(node)
      is_special(node, 'item')
    end

    def is_key(node)
      is_special(node, 'key')
    end

    def is_special(node, verb)
      return true if  node.name == verb
      node.namespace_scopes.any? do |ns|
        ns.href == XML_NS && node.name == "#{ns.prefix}:#{verb}"
      end
    end

    def localname(node)
      p = node.name.index(':')
      p ? node.name[p+1, -1] : node.name
    end
  end
end
