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

##
# To make this example work, you need to install the example_modular_inputs.spl
# application in the examples directory in your Splunk instance. It provides
# two modular inputs called test1 and test2.

require 'splunk-sdk-ruby'

# How to get to the Splunk server. Edit this to match your
# own Splunk install.
config = {
    :scheme => :https,
    :host => "localhost",
    :port => 8090,
    :username => "admin",
    :password => "admin"
}

# First open a connection to Splunk.
service = Splunk::connect(config)

# List the modular inputs on the server.
puts "Modular inputs:"
service.modular_input_kinds.each do |mi|
  puts "  #{mi["title"]} (#{mi.name})"
end

# List the parameters to test1
puts
puts "Arguments to test1:"
puts
args = service.modular_input_kinds["test1"].arguments
args.each do |key, val|
  puts "  Arg: #{key}"
  puts "  Human-readable title: #{val["title"]}"
  puts "  Description: #{val["description"]}"
  puts "  Req on\tReq on"
  puts "  create\tedit\tOrder\tType"
  puts "  #{val["required_on_create"]}\t\t\t#{val["required_on_edit"]}\t\t#{val["order"]}\t#{val["data_type"]}"
  puts
end

# Now we'll create an input of kind test1. The only field we must provide
# is 'required_on_create', which has the required_on_create=1 in its definition.
# All the other arguments are optional.
test1_inputs = service.inputs["test1"]

# Create an input of kind test1.
INPUT_NAME = "my_input"
if test1_inputs.has_key?(INPUT_NAME)
  test1_inputs.delete(INPUT_NAME)
end
my_input = test1_inputs.create(
    INPUT_NAME,
    :required_on_create => "boris",
    :number_field => 33
)

# Print the values of the fields. In the output, number_field and
# required_on_create will be set, but all others will have no value.
puts "Initial state:"
args.keys().each do |arg|
  puts "  #{arg}: #{my_input[arg] || "(value not set)"}"
end

# Now we update the input kind. The argument 'arg_required_on_edit' has
# required_on_edit=1, so we have to send a value for it when we update
# the input.
my_input.update(:boolean_field => true, :arg_required_on_edit => "meep")
my_input.refresh() # We have to refresh to see the changes we made.

puts
puts "After update:"
args.keys().each do |arg|
  puts "  #{arg}: #{my_input[arg] || "(value not set)"}"
end

# Delete the input we created.
my_input.delete()


