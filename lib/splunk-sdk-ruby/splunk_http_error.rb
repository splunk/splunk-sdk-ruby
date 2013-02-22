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
# Defines an exception to carry all errors returned by Splunk.

require_relative 'xml_shim'

module Splunk
  ##
  # Exception to represent all errors returned from Splunkd.
  #
  # The important information about the error is available as a set of
  # accessors:
  #
  # * +code+: The HTTP error code returned.
  # * +reason+: The reason field of the HTTP response header.
  # * +detail+: The detailed error message Splunk sent in the response body.
  #
  # You can also get the original response body from +body+ and any HTTP
  # headers returns from +headers+.
  #
  class SplunkHTTPError < StandardError
    attr_reader :reason, :code, :headers, :body, :detail

    def initialize(response)
      @body = response.body
      @detail = Splunk::text_at_xpath("//msg", response.body)
      @reason = response.message
      @code = Integer(response.code)
      @headers = response.each().to_a()

      super("HTTP #{@code.to_s} #{@reason}: #{@detail || ""}")
    end
  end
end
