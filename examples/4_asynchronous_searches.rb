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

# For longer running jobs, you don't want to wait until the job finishes, as
# create_oneshot in 3_retrieve_data.rb does. In this case, use the
# create_search method of Service. Instead of returning a stream, it creates
# an asynchronous job on the server and returns a Job object referencing it.
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