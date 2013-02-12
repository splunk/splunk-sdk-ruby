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
# Provides +Collection+, representing collections in Splunk.
#

require_relative 'ambiguous_entity_reference'
require_relative 'atomfeed'
require_relative 'entity'
require_relative 'splunk_http_error'
require_relative 'synonyms'

module Splunk
  # Class representing a collection in Splunk.
  #
  # +Collection+s are groups of items, usually of class +Entity+ or one of its
  # subclasses, but occasionally another +Collection+. Usually you will obtain
  # a +Collection+ by calling one of the convenience methods on +Service+.
  #
  # +Collection+s are enumerable, and implement many of the methods found on
  # +Hash+, so methods like +each+, +select+, and +delete_if+ all work, as does
  # fetching a member of the +Collection+ with +[]+.
  #
  class Collection
    include Enumerable
    extend Synonyms

    def initialize(service, resource, entity_class=Entity)
      @service = service
      @resource = resource
      @entity_class = entity_class

      # @infinite_count declares the value used for listing all the entities
      # in a collection. It is usually -1, but some collections use 0.
      @infinite_count = -1

      # @always_fetch tells whether, when creating an entity in this collection
      # never to bother trying to parse the response, and to always fetch
      # the new state after the fact. This is necessary for some collections,
      # such as users, which don't return the newly created object.
      @always_fetch = false
    end

    ##
    # The service via which this +Collection+ refers to Splunk.
    #
    # Returns: a +Service+.
    #
    attr_reader :service

    ##
    # The path after the namespace to reach this collection.
    #
    # For example, for apps +resource+ will be +["apps", "local"]+.
    #
    # Returns: an +Array+ of +String+s.
    #
    attr_reader :resource

    ##
    # The class used to represent members of this +Collection+.
    #
    # By default this will be +Entity+, but many collections such as jobs
    # will use a subclass of it (in the case of jobs, the +Job+ class), or
    # even another collection (+ConfigurationFile+ in the case of
    # configurations).
    #
    # Returns: a class.
    #
    attr_reader :entity_class

    ##
    # Find the first entity in the collection with the given name.
    #
    # Optionally, you may provide a _namespace_. If there are multiple entities
    # visible in this collection named _name_, you _must_ provide a namespace
    # or +assoc+ will raise an +AmbiguousEntityReference+ error.
    #
    # Returns: an +Array+ of +[+_name_+, +_entity_+]+ or +nil+ if there is
    # no matching element.
    #
    def assoc(name, namespace=nil)
      entity = fetch(name, namespace)
      if entity.nil?
        return nil
      else
        return [entity.name, entity]
      end
    end

    ##
    # Convert an Atom entry into an entity in this collection.
    #
    # The Atom entry should be in the form of an entry from +AtomFeed+.
    #
    # Returns: An object of class +@entity_class+.
    #
    def atom_entry_to_entity(entry)
      name = entry["title"]
      namespace = Splunk::eai_acl_to_namespace(entry["content"]["eai:acl"])

      @entity_class.new(service=@service,
                        namespace=namespace,
                        resource=@resource,
                        name=name,
                        state=entry)
    end

    ##
    # Creates an item in this collection.
    #
    # The _name_ argument is required. All other arguments are passed as a hash,
    # though they vary from collection to collection.
    #
    # Returns: the created entity.
    #
    # *Example:*
    #     service = Splunk::connect(:username => 'admin', :password => 'foo')
    #     service.users.create('jack',
    #       :password => 'mypassword',
    #       :realname => 'Jack_be_nimble',
    #       :roles => ['user'])
    #
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

      response = @service.request(request_args)

      if @always_fetch
        fetch_args = {:method => :GET,
                      :resource => @resource + [name]}
        if args.has_key?(:namespace)
          fetch_args[:namespace] = args[:namespace]
        end
        response = @service.request(fetch_args)
      end
      feed = AtomFeed.new(response.body)
      raise StandardError.new("No entities returned") if feed.entries.empty?
      entity = atom_entry_to_entity(feed.entries[0])
      raise StandardError.new("Found nil entity.") if entity.nil?
      return entity
    end

    ##
    # Deletes an item from the collection.
    #
    # Entities from different namespaces may have the same name, so if you are
    # connected to Splunk using a namespace with wildcards in it, there may
    # be multiple entities in the collection with the same name. In this case
    # you must specify a namespace as well, or +delete+ will raise an
    # AmbiguousEntityReference error.
    #
    # *Example:*
    #     service = Splunk::connect(:username => 'admin', :password => 'foo')
    #     props = service.confs['props']
    #     props.delete('sdk-tests')
    #
    def delete(name, namespace=nil)
      if namespace.nil?
        namespace = @service.namespace
      end

      # We don't want to handle any cases about deleting ambiguously named
      # entities.
      if !namespace.is_exact?
        raise StandardError.new("Must provide an exact namespace to delete an entity.")
      end

      @service.request(:method => :DELETE,
                       :namespace => namespace,
                       :resource => @resource + [name])
      return self
    end

    ##
    # Delete all entities on this collection for which the block returns true.
    #
    # If block is omitted, returns an enumerator over all members of the
    # collection.
    #
    def delete_if(&block)
      # Without a block, just return an enumerator
      return each() if !block_given?

      values.each() do |entity|
        if block.call(entity)
          delete(entity.name, entity.namespace)
        end
      end

    end

    ##
    # Calls block once for each item in the collection.
    #
    # +each+ takes three optional arguments as well:
    #
    # * +count+ sets the maximum number of entities to fetch (integer >= 0)
    # * +offset+ sets how many items to skip before returning items in the
    #   collection (integer >= 0)
    # * +page_size+ sets how many items at a time should be fetched from the
    #   server and processed before fetching another set.
    #
    # The block is called with the entity as its argument.
    #
    # If the block is omitted, returns an enumerator over all members of the
    # entity.
    #
    # *Example:*
    #     service = Splunk::connect(:username => 'admin', :password => 'foo')
    #     service.loggers.each do |key, logger|
    #       puts logger.name + ":" + logger['level']
    #     end
    #
    def each(args={})
      enum = Enumerator.new() do |yielder|
        count = args.fetch(:count, @infinite_count)
        offset = args.fetch(:offset, 0)
        page_size = args.fetch(:page_size, nil)

        if !page_size.nil?
          # Do pagination. Fetch page_size at a time
          current_offset = offset
          remaining_count = count
          while remaining_count > 0
            n_entities = 0
            each(:offset => current_offset,
                 :count => [remaining_count, page_size].min) do |entity|
              n_entities += 1
              yielder << entity
            end

            if n_entities < page_size
              break # We've reached the end of the collection.
            else
              remaining_count -= n_entities
              current_offset += n_entities
            end
          end
        else
          # Fetch the specified range in one pass.
          response = @service.request(:resource => @resource,
                                      :query => {"count" => count.to_s,
                                                 "offset" => offset.to_s})
          feed = AtomFeed.new(response.body)
          feed.entries.each() do |entry|
            entity = atom_entry_to_entity(entry)
            yielder << entity
          end
        end
      end

      if block_given?
        enum.each() { |e| yield e }
      else
        return enum
      end
    end

    ##
    # Identical to +each+.
    #
    synonym "each_value", "each"

    ##
    # Identical to +each+, but the block is passed the entity's name.
    #
    def each_key(args={}, &block)
      each(args).map() { |e| e.name }.each(&block)
    end

    ##
    # Identical to +each+, but the block is passed both the entity's name,
    # and the entity.
    #
    def each_pair(args={}, &block)
      each(args).map() { |e| [e.name, e] }.each(&block)
    end

    ##
    # Return whether there are any entities in this collection.
    #
    # Returns: +true+ or +false+.
    #
    def empty?()
      return length() == 0
    end

    ##
    # Fetch _name_ from this collection.
    #
    # If _name_ does not exist, returns +nil+. Otherwise returns the element.
    # If, due to wildcards in your namespace, there are two entities visible
    # in the collection with the same name, fetch will raise an
    # AmbiguousEntityReference error. You must specify a namespace in this
    # case to disambiguate the fetch.
    #
    def fetch(name, namespace=nil)
      request_args = {:resource => @resource + [name]}
      if !namespace.nil?
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

      if feed.entries.length > 1
        raise AmbiguousEntityReference.new("Found multiple entities with " +
                                               "name #{name}. Please specify a disambiguating namespace.")
      else
        atom_entry_to_entity(feed.entries[0])
      end
    end

    synonym "[]", "fetch"

    ##
    # Return whether there is an entity named _name_ in this collection.
    #
    # Returns: a boolean.
    # Synonyms: contains?, include?, key?, member?
    #
    def has_key?(name)
      begin
        response = @service.request(:resource => @resource + [name])
        return true
      rescue SplunkHTTPError => err
        if err.code == 404
          return false
        else
          raise err
        end
      end
    end

    synonym "contains?", "has_key?"
    synonym "include?", "has_key?"
    synonym "key?", "has_key?"
    synonym "member?", "has_key?"

    ##
    # Return an +Array+ of all entity names in the +Collection+.
    #
    # Returns: an +Array+ of +String+s.
    #
    def keys()
      return values().map() { |e| e.name }
    end

    ##
    # Return the number of entities in this collection.
    #
    # Returns: a nonnegative +Integer+.
    # Synonyms: +size+.
    #
    def length()
      return values().length()
    end

    synonym "size", "length"

    ##
    # Return an Array of the entities in this collection.
    #
    # +values+ takes three optional arguments:
    #
    # * +count+ sets the maximum number of entities to fetch (integer >= 0)
    # * +offset+ sets how many items to skip before returning items in the
    #   collection (integer >= 0)
    # * +page_size+ sets how many items at a time should be fetched from the
    #   server and processed before fetching another set.
    #
    # Returns: an +Array+ of +@entity_class+.
    # Synonyms: +list+, +to_a+.
    #
    def values(args={})
      each(args).to_a()
    end

    synonym "list", "values"
    synonym "to_a", "values"
  end

end
