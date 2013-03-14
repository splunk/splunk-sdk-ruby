require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class TestXMLShim < Test::Unit::TestCase
  def test_escape_string_with_rexml
    Splunk::require_xml_library(:rexml)
    assert_equal("&lt;&gt;'\"&amp;", Splunk::escape_string("<>'\"&"))
  end

  def test_escape_string_with_nokogiri
    Splunk::require_xml_library(:nokogiri)
    assert_equal("&lt;&gt;'\"&amp;", Splunk::escape_string("<>'\"&"))
  end

  def test_no_matches_with_rexml
    Splunk::require_xml_library(:rexml)
    assert_nil(Splunk::text_at_xpath("//msg", "<html>Hi</html>"))
  end

  def test_no_matches_with_nokogiri
    Splunk::require_xml_library(:nokogiri)
    assert_nil(Splunk::text_at_xpath("//msg", "<html>Hi</html>"))
  end

  def test_matches_with_nokogiri
    Splunk::require_xml_library(:nokogiri)
    m = Splunk::text_at_xpath("//msg", "<response><msg>Boris &amp; Natasha</msg></response>")
    assert_equal("Boris & Natasha", m)
  end

  def test_matches_with_rexml
    Splunk::require_xml_library(:rexml)
    m = Splunk::text_at_xpath("//msg", "<response><msg>Boris &amp; Natasha</msg></response>")
    assert_equal("Boris & Natasha", m)
  end
end