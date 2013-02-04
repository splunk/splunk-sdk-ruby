require_relative 'test_helper'
require 'splunk-sdk-ruby'
require 'json'

include Splunk

class TestResultsReader < Test::Unit::TestCase
  if nokogiri_available?
    xml_libraries = [:nokogiri, :rexml]
  else
    xml_libraries = [:rexml]
    puts "Nokogiri not installed. Skipping."
  end

  test_data = JSON::parse(open("test/resultsreader_test_data.json").read())

  xml_libraries.each do |xml_library|
    test_data.each_entry do |version, tests|
      tests.each_entry do |name, expected|
        test_name = "test_#{xml_library}_#{version.gsub(/\./, "_")}_#{name}"
        define_method(test_name.intern()) do
          Splunk::require_xml_library(xml_library)
          file = File.open("test/data/results/#{version}/#{name}.xml")
          reader = ResultsReader.new(file)
          assert_equal(expected["is_preview"], reader.is_preview?)
          assert_equal(expected["fields"], reader.fields)

          n_results = 0
          reader.each_with_index do |result, index|
            n_results += 1
            # The assert of the full data structure below works, but
            # by default Test::Unit doesn't print the diff of large
            # data structures, so for debugging purposes it's much
            # nicer to have each key checked individually as well.
            expected["results"][index].each_entry do |key, value|
              assert_equal([index, key, value],
                           [index, key, result[key]])
            end
            assert_equal(expected["results"][index], result)
          end

          assert_equal(expected["results"].length, n_results)
        end
      end
    end
  end
end