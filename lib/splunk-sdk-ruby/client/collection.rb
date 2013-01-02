module Splunk
  # Collections are groups of items, which can be Entity objects, subclasses of
  # Entity objects or Job objects.
  # They are created by calling one of many methods on the Service object.
  class Collection
    def initialize(service, path, entity_class=Entity)
      @service = service
      @path = path
      @entity_class = entity_class

      # @infinite_count declares the value used for listing all the entities
      # in a collection. It is usually -1, but some collections use 0.
      @infinite_count = -1
    end

    attr_reader :service, :path, :entity_class

    # Create an Entity from a hash of an Atom entry in this collection.
    #
    def atom_entry_to_entity(entry)
      name = entry["title"]
      namespace = eai_acl_to_namespace(entry["content"]["eai:acl"])

      @entity_class.new(service=@service,
                        namespace=namespace,
                        path=@path,
                        name=name,
                        state=entry)
    end

    # Deletes an item named <b>+name+</b>
    #
    # ==== Example - delete stanza _sdk-tests_ from _props.conf_
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   props = svc.confs['props']
    #   props.delete('sdk-tests')
    def delete(name)
      raise NotImplmentedError if @dtor.nil?
      @dtor.call(@service, name)
      return self
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
    # ==== Example - display the name and level of each logger
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.loggers.each {|logger| puts logger.name + ":" + logger['level']}
    def each(args, &block)
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
            block.call(entity)
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
        response = @service.request(:resource => @path,
                                    :query => {"count" => count.to_s,
                                               "offset" => offset.to_s})
        feed = AtomFeed.new(response.body)
        feed.entries.each() do |entry|
          entity = atom_entry_to_entity(entry)
          block.call(entity)
        end
      end
    end

    def each_pair(args, &block)
      # Synonym for each
      each(args, &block)
    end



    # Creates an item in this collection named <b>+name+</b> with optional args
    #
    # ==== Example - create a user named _jack_ and assign a password, a real name and a role
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.users.create('jack', :password => 'mypassword', :realname => 'Jack_be_nimble', :roles => ['user'])
    def create(name, args={})
      raise NotImplementedError if @ctor.nil?
      @ctor.call(@service, name, args)
      return self[name]
    end

    # Returns an item in this collection given <b>+key+</b>
    #
    # ==== Example - get an Index object called _main_
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   main = svc.indexes['main']
    def [](key)
      raise NotImplmentedError if @item.nil?
      raise KeyError if !contains?(key)
      @item.call(@service, key)
    end

    # Returns _true_ if an item called <b>+name</b> exists in the Collection
    #
    # ==== Example - does an index called _main_ exist?
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   if svc.indexes.contains?('main')
    #     puts 'index main exists'
    #   else
    #     puts 'index main does not exist'
    #   end
    def contains?(name)
      list().include?(name)
    end

    #TODO: Need method 'itemmeta'

    # Returns an Array of item names contained in this Collection
    #
    # ==== Example - list all roles
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.roles.list
    def list
      retval = []
      response = @service.context.get(@path + '?count=-1')
      record = AtomResponseLoader::load_text_as_record(response)
      return retval if !record.feed.instance_variable_defined?('@entry')
      if record.feed.entry.is_a?(Array)
        record.feed.entry.each do |entry|
          # because 'entry' is an array we don't allow dots
          retval << entry['title']
        end
      else
        retval << record.feed.entry.title
      end
      retval
    end
  end
end
