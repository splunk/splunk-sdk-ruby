require_relative "test_helper"
require "splunk-sdk-ruby"

include Splunk

# URI's classes compare by object identity, which is exactly what we
# *don't* want to do. Instead we use simple textual identity.
module URI
  class Generic
    def ==(other)
      return self.to_s == other.to_s
    end
  end

  class HTTPS
    def ==(other)
      return self.to_s == other.to_s
    end
  end

  class HTTP
    def ==(other)
      return self.to_s == other.to_s
    end
  end
end

class TestAtomFeed < SplunkTestCase
  # If Nokogiri is available, we'll test AtomFeed against both it
  # and REXML. Otherwise, we'll print a warning and test only against
  # REXML. REXML is part of the standard library in Ruby 1.9, so it will
  # always be present.
  if nokogiri_available?
    xml_libraries = [:nokogiri, :rexml]
  else
    xml_libraries = [:rexml]
    puts "Nokogiri not installed. Skipping."
  end

  test_cases = eval(open("test/atom_test_data.rb").read())

  xml_libraries.each do |xml_library|
    test_cases.each_entry do |filename, expected|
      define_method("test_#{xml_library}_#{filename}".intern()) do
        file = File.open("test/data/atom/#{filename}.xml")
        feed = Splunk::AtomFeed.new(file)

        # To make debugging easy, test the metadata a key at
        # a time, since Test::Unit doesn't display diffs.
        # Then test the whole thing at the end to make sure it all matches.
        expected[:metadata].each_entry do |key, value|
          assert_equal([filename, key, value],
                       [filename, key, feed.metadata[key]])
        end
        assert_equal(expected[:metadata], feed.metadata)

        # To make debugging easy, test each key of each entry
        # separately, since Test::Unit doesn't display diffs.
        # Then test the whole thing at the end to make sure it all matches.
        expected[:entries].each_with_index do |entry, index|
          entry.each_entry do |key, value|
            assert_equal([filename, index, key, value],
                         [filename, index, key, feed.entries[index][key]])
          end
        end
        assert_equal(expected[:entries], feed.entries)
      end
    end
  end
end

