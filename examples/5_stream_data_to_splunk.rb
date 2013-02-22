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

# Data written to Splunk with the Ruby SDK must be written to a particular
# index, so we first create an index to write to if it doesn't already
# exist.
INDEX_NAME = "my_index"

if !service.indexes.has_key?(INDEX_NAME)
  example_index = service.indexes.create(INDEX_NAME)
else
  example_index = service.indexes[INDEX_NAME]
end

# We can write single events to the index with the Index#submit method.
example_index.submit("This is a test event.")

# And we'll wait until it has probably been indexed.
sleep(1) # Indexing isn't instantaneous.
stream = service.create_oneshot("search index=#{INDEX_NAME}")
results = Splunk::ResultsReader.new(stream)
results.each do |result|
  puts result["_raw"]
end

# If you need to send more than one event, use the attach method to get an
# open socket to the index again. Sending multiple events via attach is
# significantly faster than calling submit. However, Splunk only indexes data
# from attach when either the socket is closed or it has accumulated 1MB
# of input.
socket = example_index.attach()
begin
  socket.write("The first event.\r\n")
  socket.write("The second event.\r\n")
ensure
  socket.close() # You must make sure the socket gets closed.
end

# Again we'll wait until it's probably been indexed.
sleep(3) # Indexing isn't instantaneous.
stream = service.create_oneshot("search index=#{INDEX_NAME}")
results = Splunk::ResultsReader.new(stream)
results.each do |result|
  puts result["_raw"]
end

# Finally, if we're running a version of Splunk where we can delete indexes
# (anything since 5.0), we'll delete the index we created.
if service.splunk_version[0] >= 5
  service.indexes.delete(INDEX_NAME)
end
