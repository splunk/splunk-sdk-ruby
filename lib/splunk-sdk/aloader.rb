require 'libxml'

XML_NS = 'http://dev.splunk.com/ns/rest'

#Some bitchin metaprogramming to allow "dot notation" reading from a Hash
class Hash
  def to_obj
    self.inject(Object.new) do |obj, ary| # ary is [:key, "value"]
      obj.instance_variable_set("@#{ary[0]}", ary[1])
      class << obj; self; end.instance_eval do # do this on obj's metaclass
        attr_reader ary[0].to_sym # add getter method for this ivar
      end
      obj # return obj for next iteration
    end
  end
end



class AtomResponseLoader
public

  def initialize(text, convert_to_obj=false, match=nil)
    raise ArgumentError, "text is nil" if text.nil?
    text = text.strip
    raise ArgumentError, "text size is 0" if text.size == 0
    @text = text
    @convert_to_obj = convert_to_obj
    @match = match
    @name_table = {"namespaces" => [], "names" => {}}
  end

  def load()
    parser = LibXML::XML::Parser.string(@text)
    doc = parser.parse

    #if the document is empty, bail
    return nil if not doc.child?

    if @match.nil?
      items = doc.root
    else
      items = doc.root.find('./#{@match}')
    end

    #process just the root if there are no children or just one child.
    count = items.children.size
    #return load_root(items) if count <= 1

    load_root(items)

    #process everything
    #[load_root(items)]
  end

  def self.load_text(text)
    AtomResponseLoader.new(text).load
  end

  def self.load_text_as_record(text)
    AtomResponseLoader.new(text, true).load
  end

  #Method to convert a dict to a 'dot notation' accessor object
  def self.record(hash)
    hash.to_obj
  end

private
  def load_root(node)
    return load_dict(node) if is_dict(node)
    return load_list(node) if is_list(node)
    k,v = load_elem(node)
    @convert_to_obj ? {k => v}.to_obj : {k => v}
  end

  def load_elem(node)
    name = localname(node)
    attrs = load_attrs(node)
    value = load_value(node)
    return name,value if attrs.nil?
    return name,attrs if value.nil?

    if value.instance_of?(String)
      attrs["xxtext"] = value
      return name, attrs
    end

    attrs.each { |k,v|
      value[k] = v
    }
    return name,value
  end

  def load_attrs(node)
    return nil if not node.attributes?
    attrs = {}
    node.attributes.each { |a| attrs[a.name] = a.value}
    attrs
  end

  def load_dict(node)
    value = {}
    node.each_element do |child|
      #assert(is_key(node))
      name = child.attributes['name']
      value[name] = load_value(child)
    end
    @convert_to_obj ? value.to_obj : value
  end

  def load_list(node)
    #assert(is_list(node))
    value = []
    node.each_element do |child|
      #assert(is_item(child))
      value.push(load_value(child))
    end
    value
  end

  def load_value(node)
    value = {}
    for child in node.children
      if child.node_type_name.eql?('text')
        text = child.content
        return nil if text.nil?
        text.strip!
        next if text.size == 0
        next if node.children.size > 1
        return text
      elsif child.node_type_name.eql?('element')
        return load_dict(child) if is_dict(child)
        return load_list(child) if is_list(child)
        name, item = load_elem(child)
        if value.has_key?(name)
          current = value[name]
          value[name] = [current] if not current.instance_of?(Array)
          value[name].push(item)
        else
          value[name] = item
        end
      end
    end
    return nil if value.size == 0
    @convert_to_obj ? value.to_obj : value
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
    if node.name == verb
      return true
    end
    nss = node.namespaces
    nss.each { |ns|
      if ns.href == XML_NS && node.name =="#{ns.prefix}:#{verb}"
        return true
      end
    }
    false
  end

  def localname(node)
    p = node.name.index(':')
    return node.name[p+1,-1] if p
    node.name
  end
end

#foo = SplunkData::AtomResponseLoader::load_text("<e a1='v1'>v2<b>bv2</b></e>")
#puts foo
#puts "should be: {'e' => {'a1' => 'v1', 'b' => 'bv2'}}"








