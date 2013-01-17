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
# Provides +Configurations+, a collection of configuration files in Splunk.
# +Configurations+ has an API identical to its superclass, +Collection+,
# so a user of the SDK should not have to be aware of its existance.
#

require_relative '../collection'
require_relative 'configuration_file'

module Splunk
  ##
  # Class representing a collection of configuration files.
  #
  # The API of +Configurations+ is identical to +Collection+,
  # so the user should not need to be aware of this class.
  #
  class Configurations < Collection # :nodoc:
    def initialize(service)
      super(service, PATH_CONFS, entity_class=ConfigurationFile)
    end

    def atom_entry_to_entity(entry)
      name = entry["title"]
      return ConfigurationFile.new(@service, name)
    end

    def create(name)
      # Don't bother catching the response. It either succeeds and returns
      # an empty body, or fails and throws a SplunkHTTPError.
      @service.request({:method => :POST,
                        :resource => PATH_CONFS,
                        :body => {"__conf" => name}})
      return ConfigurationFile.new(@service, name)
    end

    def delete(name)
      raise IllegalOperation.new("Cannot delete configuration files from" +
                                     " the REST API.")
    end

    def fetch(name)
      begin
        # Make a request to the server to see if _name_ exists.
        # We don't actually use any information returned from the server
        # besides the status code.
        request_args = {:resource => PATH_CONFS + [name]}
        @service.request(request_args)

        return ConfigurationFile.new(@service, name)
      rescue SplunkHTTPError => err
        if err.code == 404
          return nil
        else
          raise err
        end
      end
    end
  end
end