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

# Create a Service logged into Splunk, and print the authentication token
# that Splunk sent us.
service0 = Splunk::connect(config)
puts "Logged in service 0. Token: #{service0.token}"

# connect is a synonym for creating a Service by hand and calling login.
service1 = Splunk::Service.new(config)
service1.login()
puts "Logged in. Token: #{service1.token}"

# However, we don't always want to call login. If we have already obtained a
# valid token, we can use it instead of a username or password. In this case
# we must create the Service manually.
token_config = {
    :scheme => config[:scheme],
    :host => config[:host],
    :port => config[:port],
    :token => service1.token
}

service2 = Splunk::Service.new(token_config)
puts "Theoretically logged in. Token: #{service2.token}"

