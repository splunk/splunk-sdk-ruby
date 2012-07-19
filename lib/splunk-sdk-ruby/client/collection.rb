module Splunk
#TODO: Implement Inputs

  ##
  # Collections are groups of items, which can be Entity objects, subclasses of
  # Entity objects or Job objects.
  # They are created by calling one of many methods on the Service object.
  class Collection
    def initialize(service, path, name=nil, procs={})
      @service = service
      @path = path
      @name = name if !name.nil?
      @procs = procs
      @item = init_default(:item, nil)
      @ctor = init_default(:ctor, nil)
      @dtor = init_default(:dtor, nil)
    end

    def init_default(key, deflt) # :nodoc:
      if @procs.has_key?(key)
        return @procs[key]
      end
      deflt
    end

    # Calls block once for each item in the collection
    #
    # ==== Example - display the name and level of each logger
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.loggers.each {|logger| puts logger.name + ":" + logger['level']}
    def each(&block)  # :yields: item
      self.list().each do |name|
        yield @item.call(@service, name)
      end
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
