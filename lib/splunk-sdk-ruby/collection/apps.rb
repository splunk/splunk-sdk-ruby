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

##
# Provides a class representing a configuration file.
#

require_relative '../collection'

module Splunk
  class Apps < Collection
    def initialize(service, resource, entity_class=Entity)
      super(service, resource, entity_class)

      # On Splunk 4.2, a newly created app does not have its Atom returned.
      # Instead, an Atom entity named "Created" is returned, so we have to
      # refresh the app manually. After 4.2 is no longer supported, we can
      # remove this line.
      @always_fetch = true
    end
  end
end