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
    :password => "admin"
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

# For longer running jobs, you don't want to wait until the job finishes. In
# this case, use the create_search method of Service. Instead of returning
# a stream, it creates an asynchronous job on the server and returns a Job
# object referencing it.
job = service.create_search("search index=_internal | head 1",
                            :earliest_time => "-1d",
                            :latest_time => "now")

# Before you can do anything with a Job, you must wait for it to be ready.
# Before it is, you cannot do anything with it, even read its state.
while !job.is_ready?()
  sleep(0.1)
end

# More typically you will want to wait until the job is done and its events
# ready to retrieve. For that, use the is_done? method instead. Note that a
# job is always ready before it's done.
while !job.is_done?()
  sleep(0.1)
end

# If you want the transformed results (equivalent to what create_oneshot would
# return), call the results method on the Job. If you want the untransformed
# results, call events. You can optionally pass an offset and total count,
# which are useful to get hunks of large sets of results.
stream = job.results(:count => 1, :offset => 0)
# Or: stream = job.events(:count => 3, :offset => 0)
results = Splunk::ResultsReader.new(stream)
results.each do |result|
  puts result["_raw"]
end

# If you want to run a real time search, it must be asynchronous, and it is
# never done, so neither results or events will work. Instead, you must call
# preview (which takes the same arguments as the other two).
rt_job = service.create_search("search index=_internal | head 1",
                               :earliest_time => "rt-1h",
                               :latest_time => "rt")

while !rt_job.is_ready?()
  sleep(0.1)
end

stream = rt_job.preview()
results = Splunk::ResultsReader.new(stream)
results.each do |result|
  puts result["_raw"]
end

# Finally, you can get a collection of all the jobs on this Splunk instance.
puts "Jobs:"
service.jobs.each do |job|
  puts "  #{job.sid}: #{job["eventSearch"]}"
end