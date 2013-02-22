#--
# Copyright 2011-2013 Splunk, Inc.
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
# Provides a class representing the collection of users and roles in Splunk.
# This should look identical to Collection to the end user of the SDK.
#
# Users and roles are both case insensitive to the entity name, and neither
# returns the newly created entity.
#

module Splunk
  class CaseInsensitiveCollection < Collection
    def initialize(service, resource, entity_class=Entity)
      super(service, resource, entity_class)

      # +CaseInsensitiveCollection+ is only currently used for users and roles,
      # both of which require @+always_fetch=true+. This property is not inherent
      # to +CaseInsensitiveCollection+ in any particular way. It was just a
      # convenient place to put it.
      @always_fetch = true
    end

    # The following methods only downcase the name they are passed, and should
    # be invisible to the user.
    def create(name, args={}) # :nodoc:
      super(name.downcase(), args)
    end

    def delete(name, namespace=nil) # :nodoc:
      super(name.downcase(), namespace)
    end

    def fetch(name, namespace=nil) # :nodoc:
      super(name.downcase(), namespace)
    end

    def has_key?(name) # :nodoc:
      super(name.downcase())
    end
  end
end