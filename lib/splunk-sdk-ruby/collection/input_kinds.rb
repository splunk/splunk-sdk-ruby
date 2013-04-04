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

##
# Provide a class representing a collection of input kinds.
#
module Splunk
  ##
  # A collection of input types.
  #
  # Inputs in the Splunk REST API are arranged in what looks like a
  # directory structure, as in
  #
  #     monitor/
  #     tcp/
  #       cooked/
  #       raw/
  #     udp/
  #
  # You get the top level directory by calling +inputs+ on your +Service+.
  # Then you can use it as if it were a Hash. If you fetch an entry that has
  # subtypes, such as +tcp+, you get another +InputKinds+ containing the types
  # in that entry. If you fetch an entry that doesn't have subtypes, such as
  # "udp", then you get an +Inputs+ object (a subclass of +Collection+)
  # containing specific inputs.
  #
  # *Example*:
  #
  #      # Returns an InputKinds collection
  #      tcp_inputs = service.inputs["tcp"]
  #      tcp_inputs.has_key?("raw")    # ==> true
  #      tcp_inputs.has_key?("cooked") # ==> true
  #
  #      # A read only collection of all the inputs in Splunk.
  #      service.inputs["all"]
  #
  #      # An Inputs object containing all the UDP inputs in Splunk.
  #      service.inputs["udp"]
  #
  class InputKinds < ReadOnlyCollection
    def fetch(name, namespace=nil)
      request_args = {:resource => @resource + [name]}
      if not namespace.nil?
        request_args[:namespace] = namespace
      end

      begin
        response = @service.request(request_args)
      rescue SplunkHTTPError => err
        if err.code == 404
          return nil
        else
          raise err
        end
      end

      feed = AtomFeed.new(response.body)
      if feed.metadata["links"].has_key?("create")
        Inputs.new(@service, resource + [name])
      elsif name == "all"
        ReadOnlyCollection.new(@service, resource + [name])
      else
        InputKinds.new(@service, resource + [name])
      end
    end
  end

  ##
  # A collection of specific inputs.
  #
  class Inputs < Collection
    def initialize(service, resource)
      super(service, resource)
      @always_fetch = true
    end

    def create(name, args={})
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

      @service.request(request_args)

      # If we have created a oneshot input, no actual entity
      # is created. We return nil here in that case.
      if @resource == ["data", "inputs", "oneshot"]
        return nil
      end

      # TCP and UDP inputs have a key restrictToHost. If it is set
      # then they are created with hostname:port as their resource
      # instead of just port, and we must adjust our behavior
      # accordingly.
      if args.has_key?(:restrictToHost)
        name = args[:restrictToHost] + ":" + name
      end

      fetch_args = {:method => :GET,
                    :resource => @resource + [name]}
      if args.has_key?(:namespace)
        fetch_args[:namespace] = args[:namespace]
      end
      response = @service.request(fetch_args)

      feed = AtomFeed.new(response.body)
      raise StandardError.new("No entities returned") if feed.entries.empty?
      entity = atom_entry_to_entity(feed.entries[0])
      raise StandardError.new("Found nil entity.") if entity.nil?
      return entity
    end

  end
end
