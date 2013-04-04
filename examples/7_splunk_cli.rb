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

require 'readline'
require 'splunk-sdk-ruby'

# For console output
def cmd_exec(qstr,service)
	return Splunk::ResultsReader.new( service.create_oneshot(qstr) ).map do |res|
		res['_raw']
	end.join("\n")
end

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
# Pump blocking calls back and forth until exit or SIGINT
while line = Readline::readline('splunk> ', true)
	break if line.strip == 'exit'
	print("\n" << cmd_exec(line,service) << "\n")
end
# Lets not leave stale session tokens about
service.logout

