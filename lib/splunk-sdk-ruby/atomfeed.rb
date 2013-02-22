#--
# Copyright 2011-2013 Splunk, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"): you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#++

##
# +atomfeed.rb+ provides an +AtomFeed+ class to parse the Atom XML feeds
# returned by most of Splunk's endpoints.
#

require_relative 'xml_shim'

#--
# Nokogiri returns attribute values as objects on which we have to call
# `#text`. REXML returns Strings. To make them both work, add a `text` method to
# String that returns itself.
#++
class String # :nodoc:
  def text
    self
  end
end

#--
# For compatibility with Nokogiri, we add a method `text`, which, like 
# Nokogiri's `text` method, returns the contents without escaping entities. 
# This is identical to REXML's `value` method.
#++
#if $splunk_xml_library == :rexml
#  class REXML::Text # :nodoc:
#    def text
#      value
#    end
#  end
#end

module Splunk
  ##
  # Reads an Atom XML feed into a Ruby object.
  #
  # +AtomFeed.new+ accepts either a string or any object with a +read+ method.
  # It parses that as an Atom feed and exposes two read-only fields, +metadata+
  # and +entries+. The +metadata+ field is a hash of all the header fields of 
  # the feed. The +entries+ field is a list of hashes giving the details of 
  # each entry in the feed.
  #
  # *Example:*
  #
  #     file = File.open("some_feed.xml")
  #     feed = AtomFeed.new(file)
  #     # or AtomFeed.new(file.read())
  #     # or AtomFeed.new(file, xml_library=:rexml)
  #     feed.metadata.is_a?(Hash) == true
  #     feed.entries.is_a?(Array) == true
  #
  class AtomFeed
    public
    def initialize(text_or_stream)
      if text_or_stream.respond_to?(:read)
        text = text_or_stream.read()
      else
        text = text_or_stream
      end
      # Sanity checks
      raise ArgumentError, 'text is nil' if text.nil?
      text = text.strip
      raise ArgumentError, 'text size is 0' if text.size == 0

      if $splunk_xml_library == :nokogiri
        doc = Nokogiri::XML(text)
      else
        doc = REXML::Document.new(text)
      end
      # Skip down to the content of the Atom feed. Most of Splunk's
      # endpoints return a feed of the form
      #
      #     <feed>
      #        ...metadata...
      #        <entry>...details of entry...</entry>
      #        <entry>...details of entry...</entry>
      #        <entry>...details of entry...</entry>
      #        ...
      #     </feed>
      #
      # with the exception of fetching a single job entity from Splunk 4.3,
      # where it returns
      #
      #     <entry>...details of entry...</entry>
      #
      # To handle both, we have to check whether <feed> is there
      # before skipping.
      if doc.root.name == "feed"
        @metadata, @entries = read_feed(doc.root)
      elsif doc.root.name == "entry"
        @metadata = {}
        @entries = [read_entry(doc.root)]
      else
        raise ArgumentError, 'root element of Atom must be feed or entry'
      end
    end

    ##
    # The header fields of the feed.
    #
    # Typically this has keys such as "+author+", "+title+", and
    # "+totalResults+".
    #
    # Returns: a +Hash+ with +Strings+ as keys.
    #
    attr_reader :metadata

    ##
    # The entries in the feed.
    #
    # Returns: an +Array+ containing +Hashes+ that represent each entry in the feed.
    #
    attr_reader :entries

    private # All methods below here are internal to AtomFeed.

    ##
    # Produces a +String+ from the children of _element_.
    #
    # _element_ should be either a REXML or Nokogiri element.
    #
    # Returns: a +String+.
    #
    def children_to_s(element) # :nodoc:
      result = ""
      element.children.each do |child|
        if $splunk_xml_library == :nokogiri
          result << child.text
        else
          result << child.value
        end
      end
      result
    end

    ##
    # Reads a feed from the the XML in _feed_.
    #
    # Returns: [+metadata, entries+], where +metadata+ is a hash of feed
    # headers, and +entries+ is an +Array+ of +Hashes+ representing the feed.
    #
    def read_feed(feed)
      metadata = {"links" => {}, "messages" => []}
      entries = []

      feed.elements.each do |element|
        if element.name == "entry"
          entries << read_entry(element)
        elsif element.name == "author"
          # The author tag has the form <author><name>...</name></author>
          # so we have to fetch the value out of the inside of it.
          metadata["author"] = read_author(element)
        elsif element.name == "generator"
          # To handle elements of the form:
          #     <generator build="144175" version="5.0.2"/>
          metadata["generator"] = {}
          element.attributes.each do |name, attribute|
            metadata["generator"][name] = attribute.text
          end
        elsif element.name == "link"
          rel, uri = read_link(element)
          metadata["links"][rel] = uri
        elsif element.name == "id"
          metadata[element.name] = URI(children_to_s(element))
        elsif element.name == "messages"
          element.elements.each do |element|
            if element.name == "msg"
              metadata["messages"] << {
                  "type" => element.attributes["type"].text.intern,
                  "message" => children_to_s(element)
              }
            end
          end
        else
          metadata[element.name] = children_to_s(element)
        end
      end

      return metadata, entries
    end

    ##
    # Reads a single entry from the XML in _entry_.
    #
    # Returns: a +Hash+ representing the entry.
    #
    def read_entry(entry)
      result = {"links" => {}}
      entry.elements.each do |element|
        name = element.name
        if name == "link"
          rel, uri = read_link(element)
          result["links"][rel] = uri
        else
          value = read_entry_field(element)
          result[name] = value
        end
      end

      return result
    end

    ##
    # Reads a name and link from the XML in _link_.
    #
    # Returns: [+name, link+], where _name_ is a +String+ giving the name of
    # the link, and _link_ is a +URI+.
    #
    def read_link(link)
      # To handle elements of the form:
      #     <link href="/%252FUsers%252Ffross%252Ffile%20with%20spaces"
      # Note that the link is already URL encoded.
      uri = URI(link.attributes['href'].text)
      rel = link.attributes['rel'].text
      return rel, uri
    end

    ##
    # Reads a single field of an entry from the XML in _field_.
    #
    # Returns: a single value (either a +String+ or a +URI+).
    #
    def read_entry_field(field)
      # We have to coerce this to an Array to call length,
      # since Nokogiri defines `#length` on element sets,
      # but REXML does not.
      elements = Array(field.elements)
      if elements.length == 0 # This is a simple text field
        return read_simple_entry_field(field)
      elsif elements.length > 1
        raise ArgumentError, "Entry fields should contain one element " +
            "(found #{elements.length} in #{field.to_s}."
      elsif field.name == "author"
        return read_author(field)
      end

      # Coerce to Array because Nokogiri indexes from 0, and REXML from 1.
      # Arrays always index from 0.
      value_element = Array(field.elements)[0]
      if value_element.name == "dict"
        return read_dict(value_element)
      elsif value_element.name == "list"
        return read_list(value_element)
      end
    end

    ##
    # Reads a simple field.
    #
    # Returns: a +String+ or a +URI+.
    #
    def read_simple_entry_field(field)
      value = children_to_s(field)
      if field.name == "id"
        return URI(value)
      else
        return value
      end
    end

    ##
    # Reads a dictionary from the XML in _dict_.
    #
    # Returns: a +Hash+.
    #
    def read_dict(dict)
      result = {}
      dict.elements.each do |element|
        key = element.attributes["name"].text
        value = read_entry_field(element)
        result[key] = value
      end

      return result
    end

    ##
    # Reads an +Array+ from the XML in _list_.
    #
    # Returns: an +Array+.
    #
    def read_list(list)
      result = []
      list.elements.each do |element|
        value = read_entry_field(element)
        result << value
      end

      return result
    end

    ##
    # Reads the author from its special tag.
    #
    # Returns: a +String+.
    #
    def read_author(author)
      # The author tag has the form <author><name>...</name></author>
      # so we have to fetch the value out of the inside of it.
      #
      # In REXML, sets of elements are indexed starting at 1 to match
      # XPath. In Nokogiri they are indexed starting at 0. To work around
      # this, we coerce it to an array, which is always indexed starting at 0.
      #
      return Array(author.elements)[0].text
    end
  end
end
