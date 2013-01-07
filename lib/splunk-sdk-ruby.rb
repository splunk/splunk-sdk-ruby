# :title:Splunk SDK for Ruby
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
#
# The Splunk SDK for Ruby provides an idiomatic interface to Splunk
# from Ruby. To use it, add
#
#     require 'splunk-sdk-ruby'
#
# to the top of your source file. All the code in the SDK is in the +Splunk+
# module. Once you have included the SDK, create a connection to your Splunk
# instance with (changing host, port, username, and password to your values):
#
#     service = Splunk::Service.new(:host => "localhost",
#                                   :port => 8089,
#                                   :username => "admin",
#                                   :password => "changeme").login()
#

module Splunk
  require_relative 'splunk-sdk-ruby/xml_shim'
  require_relative 'splunk-sdk-ruby/namespace'
  require_relative 'splunk-sdk-ruby/splunk_http_error'
  require_relative 'splunk-sdk-ruby/illegal_operation'
  require_relative 'splunk-sdk-ruby/atomfeed'
  require_relative 'splunk-sdk-ruby/resultsreader'
  require_relative 'splunk-sdk-ruby/context'
  require_relative 'splunk-sdk-ruby/client'
end
