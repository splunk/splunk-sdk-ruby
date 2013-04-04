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

require 'pry'
require 'splunk-sdk-ruby'

# For console output
class SplunkShell < Splunk::Service

	def splunk_exec(qstr)
		return Splunk::ResultsReader.new( self.create_oneshot(qstr) ).map do |res|
			res['_raw']
		end.join("\n")
	end

	def splunk_shell
		while line = Readline::readline('splunk> ', true)
		        break if line.strip == 'exit'
		        print("\n" << splunk_exec(line) << "\n")
		end
	end
	
	def splunk_help
		print("\n Available Commands:\n\tsplunk_shell - launch a CLI shell\n\tsplunk_exec - execute oneshot\n")
	end
end
# How to get to the Splunk server. Edit this to match your
# own Splunk install.
config = {
    :scheme => :https,
    :host => "localhost",
    :port => 8089,
    :username => "admin",
    :password => "changemenow"
}

# First open a connection to Splunk.
#service = Splunk::connect(config)
service = SplunkShell.new(config).login
# Configure our prompt
Pry.config.prompt = proc { |obj, nest_level, _| "Splunk::#{obj.class}> " }
pry service
# Lets not leave stale session tokens about
service.logout

