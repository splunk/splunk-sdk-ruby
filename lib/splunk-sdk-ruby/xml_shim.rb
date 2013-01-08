#--
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
#++

# :enddoc:
##
# Control which XML parsing library the Splunk SDK for Ruby uses.
#
# The Splunk SDK for Ruby can use either REXML (the default library that
# ships with Ruby 1.9) or Nokogiri (a binding around the C library +libxml2+).
# Which library it tries is determined by the +$defualt_xml_library+ global
# variable.
#
# By default, this module will try to set the library to Nokogiri, and, if
# that is unavailable, will fall back to REXML. The library can be selected
# explicitly (in which case it will not use the fail back behavior) by calling
# +require_xml_library+ (which you should use in preference to setting
# +$default_xml_library+ manually, since it also takes care of checking that
# the library loads properly).
#
# You can also specify the environment variable +$RUBY_XML_LIBRARY+ in the shell
# to choose the default library. The two values are +"rexml"+ and +"nokogiri"+
# (note that they are not case sensitive). If you specify this environment
# variable, the SDK will not attempt to fall back to REXML in the absence of
# Nokogiri.

module Splunk
  ##
  # Tell the Splunk SDK for Ruby to use _library_ for XML parsing.
  #
  # The only two supported libraries for now are Nokogiri (pass +:nokogiri+ as
  # the _library_ parameter) and REXML (pass +:rexml+).
  #
  # Arguments:
  # * _library_: (+:nokogiri+ or +:rexml:+) A symbol specifying the library.
  #
  # Raises:
  # * +LoadError+ if the library requested cannot be loaded.
  #
  # Returns no value of interest.
  #
  def require_xml_library(library)
    if library == :nokogiri
      require 'nokogiri'
      $default_xml_library = :nokogiri
    else
      require 'rexml/document'
      require 'rexml/streamlistener'
      $xml_library = :rexml
    end
  end

  # In the absence of any other call to +require_xml_library+, we try to use
  # Nokogiri, and if that doesn't work, we fall back to REXML, which is shipped
  # with Ruby 1.9, and should always be there.
  if ENV['RUBY_XML_LIBRARY'].nil?
    begin
      require 'nokogiri'
      $default_xml_library = :nokogiri
    rescue LoadError
      require 'rexml/document'
      require 'rexml/streamlistener'
      $xml_library = :rexml
    end
  elsif ENV['RUBY_XML_LIBRARY'].downcase == "rexml"
    require 'nokogiri'
    $default_xml_library = :nokogiri
  elsif ENV['RUBY_XML_LIBRARY'].downcase == "nokogiri"
    require 'nokogiri'
    $default_xml_library = :nokogiri
  else # Default: try to use Nokogiri, and otherwise fall back on REXML.
    raise StandardError.new("Unknown XML library: #{ENV['RUBY_XML_LIBRARY']}")
  end

  ##
  # Return the text contained in the first element matching _xpath_ in _text_.
  #
  # Arguments:
  # * _xpath_: (+String+) An XPath specifier. It should refer to an element
  #   containing only text, not additional XML elements.
  # * _text_: (+String+) The text to search in.
  #
  # Returns: A +String+ containing the text in the first match of _xpath_,
  # or +nil+ if there was no match.
  #
  # *Examples*:
  #
  #     text_at_xpath("/set/entry", "<set><entry>Boris</entry></set>")
  #       == "Boris"
  #     text_at_xpath("/a", "<a>Alpha</a> <a>Beta</a>") == "Alpha"
  #     text_at_xpath("/a", "<b>Quill pen</b>") == nil
  #
  def text_at_xpath(xpath, text)
    if text.nil? or text.length == 0
      return nil
    elsif $xml_library == :nokogiri
      doc = Nokogiri::XML(text)
      return doc.xpath(xpath).last.content
    else
      doc = REXML::Document.new(text)
      matches = doc.elements[xpath]
      if matches
        return matches[0].value
      else
        return nil
      end
    end
  end
end

