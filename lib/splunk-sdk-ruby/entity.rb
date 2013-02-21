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

require_relative 'ambiguous_entity_reference'
require_relative 'atomfeed'
require_relative 'entity_not_ready'
require_relative 'synonyms'

module Splunk
  ##
  # Class representing individual entities in Splunk.
  #
  # +Entity+ objects represent individual items such as indexes, users, roles,
  # etc. They are usually contained within +Collection+ objects.
  #
  # The basic, identifying information for an +Entity+ (name, namespace, path
  # of the collection containing entity, and the service it's on) is all
  # accessible via getters (+name+, +namespace+, +resource+, +service+). All
  # the fields containing the +Entity+'s state, such as the capabilities of
  # a role or whether an app should check for updates, are accessible with 
  # the [] operator (for instance, +role+["capabilities"] or 
  # +app+["check_for_updates"]).
  #
  # +Entity+ objects cache their state, so each lookup of a field does not
  # make a roundtrip to the server. The state may be refreshed by calling
  # the +refresh+ method on the +Entity+.
  #
  class Entity
    extend Synonyms

    def initialize(service, namespace, resource, name, state=nil) # :nodoc:
      @service = service
      @namespace = namespace
      if !@namespace.is_exact?
        raise StandardError.new("Must provide an exact namespace to " +
                                    "Entity (found: #{@namespace}")
      end
      @resource = resource
      @name = name
      @state = state
      if !state # If the state was not provided, we need to fetch it.
        refresh()
      end
    end

    ##
    # The name of this Entity.
    #
    # Returns: a +String+.
    #
    attr_reader :name

    ##
    # The namespace of this Entity.
    #
    # Returns: a +Namespace+.
    #
    attr_reader :namespace

    ##
    # The path of the collection this entity lives in.
    #
    # For example, on an app this will be ["+apps+", "+local+"].
    #
    # Returns: an +Array+ of +Strings+.
    #
    attr_reader :resource

    ##
    # The service this entity refers to.
    #
    # Returns: a +Service+ object.
    #
    attr_reader :service

    ##
    # Deletes this entity from the server.
    #
    # Returns: +nil+.
    #
    def delete()
      @service.request({:method => :DELETE,
                        :namespace => @namespace,
                        :resource => @resource + [name]})
    end

    ##
    # Fetches the field _key_ on this entity.
    #
    # You may provide a default value. All values are returned
    # as strings.
    #
    # Returns: a +String+.
    #
    def fetch(key, default=nil)
      @state["content"].fetch(key, default)
    end

    ##
    # Fetch a field on this entity.
    #
    # Returns: a +String+.
    #
    synonym "[]", "fetch"

    ##
    # Returns a Hash of the links associated with this entity.
    #
    # The links typically include keys such as "+list+", "+edit+", or
    # "+disable+".
    #
    # Returns: a +Hash+ of +Strings+ to URL objects.
    #
    def links()
      return @state["links"]
    end

    ##
    # DEPRECATED. Use +fetch+ and [] instead (since entities now cache their
    # state).
    #
    # Returns all or a specified subset of key/value pairs on this +Entity+
    #
    # In the absence of arguments, returns a Hash of all the fields on this
    # +Entity+. If you specify one or more +Strings+ or +Arrays+ of +Strings+,
    # all the keys specified in the arguments will be returned in the +Hash+.
    #
    # Returns: a +Hash+ with +Strings+ as keys, and +Strings+ or +Hashes+ or 
    # +Arrays+ as values.
    #
    def read(*field_list)
      warn "[DEPRECATION] Entity#read is deprecated. Use [] and fetch instead."
      if field_list.empty?
        return @state["content"].clone()
      else
        field_list = field_list.flatten()
        result = {}
        field_list.each() do |key|
          result[key] = fetch(key).clone()
        end
        return result
      end
    end

    ##
    # Returns the metadata for this +Entity+.
    #
    # This method is identical to
    #
    #     entity.read('eai:acl', 'eai:attributes')
    #
    # Returns: a +Hash+ with the keys "+eai:acl+" and "+eai:attributes+".
    #
    def readmeta
      read('eai:acl', 'eai:attributes')
    end

    ##
    # Refreshes the cached state of this +Entity+.
    #
    # Returns: the +Entity+.
    #
    def refresh()
      response = @service.request(:resource => @resource + [name],
                                  :namespace => @namespace)
      if response.code == 204 or response.body.nil?
        # This code is here primarily to handle the case of a job not yet being
        # ready, in which case you get back empty bodies.
        raise EntityNotReady.new((@resource + [name]).join("/"))
      end
      # We are guaranteed a unique entity, since entities must have
      # exact namespaces.
      feed = AtomFeed.new(response.body)
      @state = feed.entries[0]
      self
    end

    ##
    # Updates the values on the Entity specified in the arguments.
    #
    # The arguments can be either a Hash or a sequence of +key+ => +value+ 
    # pairs. This method does not refresh the +Entity+, so if you want to see 
    # the new values, you must call +refresh+ yourself.
    #
    # Whatever values you pass will be coerced to +Strings+, so updating a
    # numeric field with an Integer, for example, will work perfectly well.
    #
    # Returns: the +Entity+.
    #
    # *Example*:
    #     service = Splunk::connect(:username => 'admin', :password => 'foo')
    #     index =  service.indexes['main']
    #     # You could use the string "61" as well here.
    #     index.update('rotatePeriodInSecs' => 61)
    #
    def update(args)
      @service.request({:method => :POST,
                        :namespace => @namespace,
                        :resource => @resource + [name],
                        :body => args})
      self
    end

    ##
    # Updates the attribute _key_ with _value_.
    #
    # As for +update+, _value_ may be anything that may be coerced sensibly
    # to a +String+.
    #
    # Returns: the new value.
    #
    def []=(key, value)
      update(key => value)
      value
    end

    ##
    # Disables this entity.
    #
    # After a subsequent refresh, the "disabled" field will be set to "1".
    # Note that on some entities, such as indexes in Splunk 5.x, most other
    # operations do not work until it is enabled again.
    #
    # Returns: the +Entity+.
    #
    def disable
      @service.request(:method => :POST,
                       :namespace => @namespace,
                       :resource => @resource + [name, "disable"])
      self
    end

    ##
    # Enables this entity.
    #
    # After a subsequent refresh, the "disabled" field will be set to "0".
    #
    # Returns: the +Entity+.
    #
    def enable
      @service.request(:method => :POST,
                       :namespace => @namespace,
                       :resource => @resource + [name, "enable"])
      self
    end
  end
end
