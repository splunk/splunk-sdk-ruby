require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class TestXMLShim < SplunkTestCase
  def test_no_matches_with_rexml
    require_xml_library(:rexml)
    assert_nil(text_at_xpath("//msg", "<html>Hi</html>"))
  end

  def test_no_matches_with_nokogiri
    require_xml_library(:nokogiri)
    assert_nil(text_at_xpath("//msg", "<html>Hi</html>"))
  end

  def test_matches_with_nokogiri
    Splunk::require_xml_library(:nokogiri)
    m = text_at_xpath("//msg", "<response><msg>Boris &amp; Natasha</msg></response>")
    assert_equal("Boris & Natasha", m)
  end

  def test_matches_with_rexml
    require_xml_library(:rexml)
    m = text_at_xpath("//msg", "<response><msg>Boris &amp; Natasha</msg></response>")
    assert_equal("Boris & Natasha", m)
  end
end