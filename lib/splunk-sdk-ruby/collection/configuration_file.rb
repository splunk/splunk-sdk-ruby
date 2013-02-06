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
# Provides a class representing a configuration file.
#

require_relative '../collection'

module Splunk
  ##
  # ConfigurationFile is a collection containing configuration stanzas.
  #
  # This class's API is identical to +Collection+, so a user should not
  # have to be aware of its existance.
  #
  class ConfigurationFile < Collection # :nodoc:
    # This class is unusual: it is the element of a collection itself,
    # and its elements are entities.

    def initialize(service, name, namespace)
      super(service, ["configs", "conf-#{name}"], entity_class=Stanza)
      @name = name
      @namespace = namespace
    end

    def create(name, args={})
      body_args = args.clone()
      if !args.has_key?(:namespace)
        body_args[:namespace] = @namespace
      end
      super(name, body_args)
    end

    attr_reader :name
  end
end
