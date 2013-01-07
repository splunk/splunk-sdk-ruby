require_relative 'ambiguous_entity_reference'
require_relative 'synonyms'

module Splunk
  # Collections are groups of items, which can be Entity objects, subclasses of
  # Entity objects or Job objects.
  # They are created by calling one of many methods on the Service object.
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
    end

    attr_reader :service, :resource, :entity_class

    def assoc(name, namespace=nil)
      entity = fetch(name, namespace)
      if entity.nil?
        return nil
      else
        return [entity.name, entity]
      end
    end

    # Create an Entity from a hash of an Atom entry in this collection.
    #
    def atom_entry_to_entity(entry)
      name = entry["title"]
      namespace = eai_acl_to_namespace(entry["content"]["eai:acl"])

      @entity_class.new(service=@service,
                        namespace=namespace,
                        resource=@resource,
                        name=name,
                        state=entry)
    end

    # Creates an item in this collection named _name_ with optional args.
    #
    # Returns the created entity.
    #
    # ==== Example - create a user named _jack_ and assign a password, a real name and a role
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.users.create('jack', :password => 'mypassword', :realname => 'Jack_be_nimble', :roles => ['user'])
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
      feed = AtomFeed.new(response.body)
      raise StandardError.new("No entities returned") if feed.entries.empty?
      entity = atom_entry_to_entity(feed.entries[0])
      raise StandardError.new("Found nil entity.") if entity.nil?
      return entity
    end

    # Deletes an item named _name_ from the collection.
    #
    # Entities from different namespaces may have the same name, so if you are
    # connected to Splunk using a namespace with wildcards in it, there may
    # be multiple entities in the collection with the same name. In this case
    # you must specify a namespace as well, or `delete` will raise an
    # AmbiguousEntityReference error.
    #
    # ==== Example - delete stanza _sdk-tests_ from _props.conf_
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   props = svc.confs['props']
    #   props.delete('sdk-tests')
    def delete(name, namespace=nil)
      if namespace.nil?
        namespace = @service.namespace
      end

      # We may have multiple entities matching _name_, in which case we insist
      # that the caller provide a namespace that disambiguates the name.
      response = @service.request(:resource => @resource + [name],
                                  :namespace => namespace)
      feed = AtomFeed.new(response.body)
      if feed.entries.length > 1
        raise AmbiguousEntityReference.new("Multiple entities named " +
                                               "#{name}. Please specify a" +
                                               "namespace.")
      end

      # At this point we know that the name is unambiguous, so we delete it.
      @service.request(:method => :DELETE,
                       :namespace => namespace,
                       :resource => @resource + [name])
      return self
    end

    # Delete all entities on this collection for which the block returns true.
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

    # Calls block once for each item in the collection.
    #
    # `each` takes three optional arguments as well:
    #
    # * `count` sets the maximum number of entities to fetch (integer >= 0)
    # * `offset` sets how many items to skip before returning items in the
    #   collection (integer >= 0)
    # * `page_size` sets how many items at a time should be fetched from the
    #   server and processed before fetching another set.
    #
    # The block is called with the entity as its argument.
    #
    # ==== Example - display the name and level of each logger
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.loggers.each {|key, logger| puts logger.name + ":" + logger['level']}
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

    synonym "each_value", "each"

    def each_key(args={}, &block)
      each(args).map() {|e| e.name}.each(&block)
    end

    def each_pair(args={}, &block)
      each(args).map() {|e| [e.name, e]}.each(&block)
    end

    # Return whether there are any entities in this collection.
    #
    def empty?()
      return length() == 0
    end

    # Fetch _name_ from this collection.
    #
    # If _name_ does not exist, return nil. Otherwise return an Entity.
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

    # Return whether there is an entity named _name_ in this collection.
    #
    # Returns a boolean.
    # Synonyms: contains?, include?, key?, member?
    def has_key?(name)
      begin
        response = @service.request(:resource=>@resource + [name])
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

    def keys()
      return values().map() {|e| e.name}
    end

    # Return the number of entities in this collection.
    #
    def length()
      return values().length()
    end

    synonym "size", "length"

    # Return an array of the entities in this collection.
    #
    # `values` takes three optional arguments:
    #
    # * `count` sets the maximum number of entities to fetch (integer >= 0)
    # * `offset` sets how many items to skip before returning items in the
    #   collection (integer >= 0)
    # * `page_size` sets how many items at a time should be fetched from the
    #   server and processed before fetching another set.
    #
    def values(args={})
      each(args).to_a()
    end

    synonym "list", "values"
    synonym "to_a", "values"
  end

end
