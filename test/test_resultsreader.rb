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

  def assert_results_reader_equals(expected, reader)
    assert_equal(expected["is_preview"], reader.is_preview?)
    assert_equal(expected["fields"], reader.fields)

    n_results = 0
    reader.each_with_index do |result, index|
      n_results += 1
      expected_fields = expected["results"][index]["fields"]
      # The assert of the full data structure below works, but
      # by default Test::Unit doesn't print the diff of large
      # data structures, so for debugging purposes it's much
      # nicer to have each key checked individually as well.
      expected_fields.each_entry do |key, value|
        assert_equal([index, key, value],
                     [index, key, result[key]])
      end
      assert_equal(expected_fields, result)
      assert_equal(expected["results"][index]["RAW_XML"], result.segmented_raw())
    end
    assert_equal(expected["results"].length, n_results)
  end

  test_data = JSON::parse(open("test/data/resultsreader_test_data.json").read())
  export_data = JSON::parse(open("test/data/export_test_data.json").read())

  xml_libraries.each do |xml_library|
    test_data.each_entry do |version, tests|
      tests.each_entry do |name, expected|
        test_name = "test_#{xml_library}_#{version.gsub(/\./, "_")}_#{name}"
        define_method(test_name.intern()) do
          Splunk::require_xml_library(xml_library)
          file = File.open("test/data/results/#{version}/#{name}.xml")
          reader = ResultsReader.new(file)
          assert_results_reader_equals(expected, reader)
        end
      end
    end

    export_data.each_entry do |version, tests|
      # without preview via ResultsReader
      test_name = "test_#{xml_library}_#{version.gsub(/\./, "_")}_export_via_results_reader"
      define_method(test_name.intern) do
        Splunk::require_xml_library(xml_library)
        raw_file = File.open("test/data/export/#{version}/export_results.xml")
        file = Splunk::ExportStream.new(raw_file)
        found = ResultsReader.new(file)
        expected = tests["without_preview"]
        assert_results_reader_equals(expected, found)
      end

      # without_preview
      test_name = "test_#{xml_library}_#{version.gsub(/\./, "_")}_sans_preview"
      define_method(test_name.intern) do
        Splunk::require_xml_library(xml_library)
        raw_file = File.open("test/data/export/#{version}/export_results.xml")
        file = Splunk::ExportStream.new(raw_file)
        reader = MultiResultsReader.new(file)
        found = reader.final_results()
        expected = tests["without_preview"]
        assert_results_reader_equals(expected, found)
      end

      # with preview
      test_name = "test_#{xml_library}_#{version.gsub(/\./, "_")}_with_preview"
      define_method(test_name.intern) do
        Splunk::require_xml_library(xml_library)
        raw_file = File.open("test/data/export/#{version}/export_results.xml")
        file = Splunk::ExportStream.new(raw_file)
        multireader = MultiResultsReader.new(file)
        n_results_sets = 0
        readers = []
        multireader.each_with_index do |rr, index|
          readers << rr
          expected = tests["with_preview"][index]
          assert_results_reader_equals(expected, rr)
          n_results_sets += 1
        end
        assert_equal(tests["with_preview"].length, n_results_sets)
        assert_raise do # Out of order invocation should raise an error
          readers[0].each()
        end
      end

      # nonreporting
      test_name = "test_#{xml_library}_#{version.gsub("/\./", "_")}_nonreporting"
      if tests.has_key?("nonreporting")
        define_method(test_name.intern) do
          Splunk::require_xml_library(xml_library)
          file = File.open("test/data/export/#{version}/nonreporting.xml")
          multireader = MultiResultsReader.new(file)
          n_results_sets = 0
          readers = []
          multireader.each_with_index do |rr, index|
            readers << rr
            expected = tests["nonreporting"]
            assert_results_reader_equals(expected, rr)
            n_results_sets += 1
          end
          assert_equal(1, n_results_sets)
        end
      end

    end
  end


end