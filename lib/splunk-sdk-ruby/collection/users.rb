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

require_relative '../collection'
require_relative '../entity'

##
# Provides a class representing the collection of users in Splunk.
# This should look identical to the end user of the SDK.
#

module Splunk
  class Users < Collection
    def initialize(service)
      super(service, PATH_USERS, Entity)

      @always_fetch = true
    end

    ##
    # Creates an item in this collection.
    #
    # This method only exists because the users endpoints don't return the
    # created entity.
    #
    def create(name, args={}) # :nodoc:
      super(name.downcase(), args)
    end
  end
end