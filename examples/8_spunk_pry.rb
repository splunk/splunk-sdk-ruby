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
# Wordplay for metaprogramming
require 'active_support/inflector'

# For console output
class SplunkShell < Splunk::Service

	# Raw log access for deleting/changing
	attr_accessor :raw_log
	# ActiveSupport prefers this
	alias :indices :indexes
	def initialize(opts={})
		super
		# Extend this as needed, search, stats, etc. 
		#Can resubmit to splunk if needed
		@raw_log = {}
	end

	# Execute query, log everything, return raw output string
	def splunk_exec(qstr)
		results = self.create_oneshot(qstr)
		raw_log[qstr] = {Time.now.to_s => results}
		return Splunk::ResultsReader.new(results).map do |res|
			res['_raw']
		end.join("\n")
	end

	# Create JSON representation of parsed raw_log
	def splunk_log
		clear_text = {}
		raw_log.each {|qry,res|
			clear_text[qry] = {res.keys.first => Splunk::ResultsReader.new(*res.values).to_a}
		}
		clear_text
	end
			
	# CLI for splunk
	def splunk_shell
		while line = Readline::readline('splunk> ', true)
		        break if line.strip == 'exit'
		        print("\n" << splunk_exec(line) << "\n")
		end
	end
	
	# Should get smarter as this grows
	def splunk_help
		print("\n Available Commands:\n\t#{self.class.instance_methods(false).map(&:to_s).select {|m| m !~/^raw/}.join("\n\t")}\n\t")
	end

	# Common getters and setters
	%w{index app input}.each do  |meth|
		# The stock Service methods are none too readable
		define_method("get_#{meth.pluralize}") {
			self.send(meth.pluralize.intern).map(&:name)
		}
		# Get current
		define_method(meth) {
			eval("@#{meth}")
		}
		# Set current
		define_method("set_#{meth}") do |value|
			puts value
			eval("@#{meth} = self.send(meth.pluralize.intern)['#{value.strip}']")
		end
	end
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

# First open a connection to Splunk, login.
service = SplunkShell.new(config).login
# Configure our prompt
Pry.config.prompt = proc { |obj, nest_level, _| "Splunk::#{obj.class}> " }
# Start the REPL
pry service
# Lets not leave stale session tokens about
service.logout

