# Copyright 2011-2012 Splunk, Inc.
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

# atomfeed.rb provides an AtomFeed class to read the Atom XML feeds returned by
# most of Splunk's endpoints.
require 'nokogiri'

module Splunk

  # Read an Atom XML feed into a Ruby object.
  #
  # AtomFeed.new accepts either a string or any object with a read method.
  # It parses that as an Atom feed and exposes two read-only fields, metadata
  # and entries. metadata is a hash of all the header fields of the feed.
  # entries is a list of hashes giving the details of each entry in the
  # feed.
  #
  # Example:
  #
  #     file = File.open("some_feed.xml")
  #     feed = AtomFeed.new(file) # or AtomFeed.new(file.read())
  #     feed.metadata.is_a?(Hash) == true
  #     feed.entries.is_a?(Array) == true
  class AtomFeed
    public

    # Hash containing all the header fields of the feed.
    attr_reader :metadata
    # Array containing hashes representing each entry in the feed.
    attr_reader :entries

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

      doc = Nokogiri::XML(text)
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
      # To handle both, we have to check if <feed> is there
      # or not before skipping.
      if doc.root.name == "feed"
        @metadata, @entries = read_feed(doc.root)
      elsif doc.root.name == "entry"
        @metadata = {}
        @entries = [read_entry(doc.root)]
      else
        raise ArgumentError, 'root element of Atom must be feed or entry'
      end
    end

    private
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
          metadata[element.name] = URI(element.children.to_s)
        elsif element.name == "messages"
          # No idea what these look like. Try to get one with messages.
        else
          metadata[element.name] = element.children.to_s
        end
      end

      return metadata, entries
    end

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

    def read_link(link)
      # To handle elements of the form:
      #     <link href="/%252FUsers%252Ffross%252Ffile%20with%20spaces"
      # Note that the link is already URL encoded.
      uri = URI(link.attributes['href'].text)
      rel = link.attributes['rel'].text
      return rel, uri
    end

    def read_entry_field(field)
      if field.elements.length == 0 # This is a simple text field
        return read_simple_entry_field(field)
      elsif field.elements.length > 1
        raise ArgumentError, "Entry fields should contain one element " +
            "(found #{field.elements.length} in #{field.to_s}."
      elsif field.name == "author"
        return read_author(field)
      end

      value_element = field.elements[0]
      if value_element.name == "dict"
        return read_dict(value_element)
      elsif value_element.name == "list"
        return read_list(value_element)
      end
    end

    def read_simple_entry_field(field)
      if field.name == "id"
        return URI(field.children.to_s)
      else
        return field.children.to_s
      end
    end

    def read_dict(dict)
      result = {}
      dict.elements.each do |element|
        key = element.attributes["name"].text
        value = read_entry_field(element)
        result[key] = value
      end

      return result
    end

    def read_list(list)
      result = []
      list.elements.each do |element|
        value = read_entry_field(element)
        result << value
      end

      return result
    end

    def read_author(author)
      # The author tag has the form <author><name>...</name></author>
      # so we have to fetch the value out of the inside of it.
      return author.elements[0].text
    end
  end

end
