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

require 'splunk-sdk-ruby'

# How to get to the Splunk server. Edit this to match your
# own Splunk install.
config = {
    :scheme => :https,
    :host => "localhost",
    :port => 8089,
    :username => "admin",
    :password => "changeme"
}

# First open a connection to Splunk.
service = Splunk::connect(config)

# The simplest way to get data out of Splunk is with a oneshot search. A oneshot
# search creates a synchronous search. The call blocks until the search finishes
# and then returns a stream containing the events.
stream = service.create_oneshot("search index=_internal | head 1")

# By default the stream contains XML, which you can parse into proper events
# with the Ruby SDK's ResultsReader class. You can call fields on the
# ResultsReader to get an Array of Strings giving the names of all the fields
# that may appear in any of the events, or call each on it to iterate over
# the results.
results = Splunk::ResultsReader.new(stream)

puts "Fields: #{results.fields}"
results.each do |result|
  puts "#{result["_raw"]}"
end
puts

# You can also tell create_oneshot to return JSON or CSV by specifying the
# :output_mode argument to be "json" or "csv", respectively, but the Ruby SDK
# provides no support beyond what is already available in Ruby to parse either
# of these formats.
stream = service.create_oneshot("search index=_internal | head 1",
                                :output_mode => "json")
puts stream
puts

# Hash arguments like :output_mode are how you set various parameters to the
# search, as :earliest_time and :latest_time.
stream = service.create_oneshot("search index=_internal | head 1",
                                :earliest_time => "-1h",
                                :latest_time => "now")
results = Splunk::ResultsReader.new(stream)
results.each do |result|
  puts "#{result["_raw"]}"
end

# If you only need the events Splunk has returned, without any of the
# transforming search commands, you can call create_stream instead. It is
# identical to create_oneshot, but returns the events produced before any
# transforming search commands, and will thus run somewhat faster.
stream = service.create_stream("search index=_internal | head 1",
                               :earliest_time => "-1h",
                               :latest_time => "now")
results = Splunk::ResultsReader.new(stream)
results.each do |result|
  puts "#{result["_raw"]}"
end



