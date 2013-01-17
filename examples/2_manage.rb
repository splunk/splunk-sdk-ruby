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

# First we connect to Splunk. We'll use this service for all the work in this
# example.
service = Splunk::connect(config)

# Service provides convenience methods to get to the various collections in
# Splunk. For example, we'll list all the apps and all the users.
puts "Apps:"
service.apps.each do |app|
  puts "  #{app.name}"
end

puts
puts "User:"
service.users.each do |user|
  puts "  #{user.name}"
end

# Collections have most of the methods you would expect from Hash.
puts
puts "Apps starting with s:"
service.apps.select do |app|
  app.name.start_with?("s")
end.each do |app|
  puts "  #{app.name}"
end

# Collections have create and delete methods which do what you would expect.
# create methods all take the name of the entity to create as the sole
# positional argument, and a hash of other arguments, and returns an object
# representing the new entity.
new_user = service.users.create("a-new-user",
                                :password => "some password",
                                :email => "harry@nowhere.com",
                                :roles => ["power"])

puts
puts "User in collection: #{service.users.member?("a-new-user")}"
matches = service.users["a-new-user"].name == new_user.name
puts "User returned by create matches user fetched: #{matches}"

service.users.delete("a-new-user")
puts "User still in collection after delete: #{service.users.member?("a-new-user")}"

# You can access the fields on entites returned from collections as if
# they were keys in a dictionary.
new_user = service.users.create("a-new-user",
                                :password => "some password",
                                :email => "harry@nowhere.com",
                                :roles => ["power", "admin"])

puts
puts "Roles on a-new-user: #{new_user["roles"]}"
puts "Email of a-new-user: #{new_user["email"]}"

# To update fields, call the update method (or you can use []= if you only want
# to update a single field, but each call to it makes a round trip to the
# Splunk server, while update makes one call).
new_user["email"] = "petunia@nowhere.com"
new_user.update("email" => "edward@nowhere.com", "roles" => ["power"])

# If you immediately fetch the fields, you'll still see the old values, though.
# Entities cache their state, and you must call refresh to get the new state.
new_user.refresh()
puts
puts "New email: #{new_user["email"]}"
puts "New roles: #{new_user["roles"]}"

# And finally, we'll delete this user again.
service.users.delete("a-new-user")