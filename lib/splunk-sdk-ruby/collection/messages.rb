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

##
# Provides a collection representing system-wide messages on Splunk.
#

module Splunk
  ##
  # Collection representing system-wide messages on Splunk.
  #
  # There is no API difference from +Collection+, and so no reason
  # for a user to be aware of this class.
  #
  class Messages < Collection # :nodoc:
    def create(name, args)
      body_args = args.clone()
      body_args["name"] = name

      request_args = {
          :method => :POST,
          :resource => @resource,
          :body => body_args
      }
      if args.has_key?(:namespace)
        request_args[:namespace] = body_args.delete(:namespace)
      end

      response = @service.request(request_args)
      entity = Message.new(@service, namespace("system"),
                           @resource, name)
      return entity
    end

  end
end
