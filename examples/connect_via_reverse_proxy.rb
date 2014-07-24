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

# Your client certififcate that grants access to the reverse proxy.
CERT_PATH = "#{ENV['HOME']}/.ssl/client.p12"
CERT_PASS = '12changeme34'
p12 = OpenSSL::PKCS12.new(File.read(CERT_PATH), CERT_PASS)

# How to get to the Splunk server that lives behind a reverse proxy
# that requires a client certificate to access
# and when a HTTP proxy is required to leave the local network.
# Edit this to match your own server setup.
config = {
    :proxy => Net::HTTP::Proxy('myproxy.intranet.example.com', 80),
    :scheme => :https,
    :host => "externalservices.example.com",
    :port => 443,
    :path_prefix => '/splunk/api/',
    :ssl_client_cert => p12.certificate,
    :ssl_client_key  => p12.key,
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
    :proxy => config[:proxy],
    :scheme => config[:scheme],
    :host => config[:host],
    :port => config[:port],
    :path_prefix => config[:path_prefix],
    :ssl_client_cert => config[:ssl_client_cert],
    :ssl_client_key  => config[:ssl_client_key],
    :token => service1.token
}

service2 = Splunk::Service.new(token_config)
puts "Theoretically logged in. Token: #{service2.token}"

