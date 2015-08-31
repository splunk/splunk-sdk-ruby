#--
# Copyright 2011-2015 Splunk, Inc.
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
    :password => "changeme",
    # Set basic = true to use basic auth instead of token auth
    :basic => true
}

# Create a Service logged into Splunk.
service = Splunk::connect(config)

# Access some resource
num_apps = service.apps().length
puts "Found #{num_apps} apps on #{config[:host]}"

# Mock the behavior of a load balancer
config[:host] = "127.0.0.1"
service = Splunk::connect(config)

# Access some resource again
num_apps = service.apps().length
puts "Found #{num_apps} apps on #{config[:host]}"