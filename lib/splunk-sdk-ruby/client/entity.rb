module Splunk
# Entity objects represent individual items such as indexes, users, roles, etc.
  # They are usually contained within Collection objects
  class Entity
    # The name of this Entity
    attr_reader :name

    def initialize(service, namespace, resource, name, state=nil) # :nodoc:
      @service = service
      @namespace = namespace
      @resource = resource
      @name = name
      @state = state
    end

    # Access an individual attribute named <b>+key+</b>.
    # Note that this results in an HTTP round trip, fetching all values for the Entity even though a single
    # attribute is returned.
    #
    # ==== Returns
    # A String representing the attribute fetched
    #
    # ==== Example - Display the cold path for index 'main'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   index = svc.indexes['main']
    #   puts index['coldPath']
    def [](key)
      obj = read([key])
      obj[key]
    end

    # Updates an individual attribute named <b>+key+</b> with String <b>+value+</b>
    #
    # ==== Returns
    # The new value
    #
    # ==== Example - Set the 'rotateValueInSecs' to 61 on index 'main'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   index =  svc.indexes['main']
    #   index['rotatePeriodInSecs'] = '61'  #Note that you cannot use the number 61.  It must be a String.
    def []=(key, value)
      update(key => value)
    end

    # Return all or a specified subset of attribute/value pairs for this Entity
    #
    # ==== Returns
    # A Hash of all attributes and values for this Entity.  If Array <b>+field_list+</b> is specified,
    # only those fields are returned.  If a field does not exist, nil is returned for it's value.
    #
    # ==== Example 1 - Return a Hash of all attribute/values for index 'main'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.indexes['main'].read
    #     {"assureUTF8"=>"0", "blockSignSize"=>"0", "blockSignatureDatabase"=>"_blocksignature",....}
    #
    # ==== Example 2 - Return a Hash of only the specified attribute/values for index 'main'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.indexes['main'],read(['coldPath', 'blockSignSize'])
    #     {"coldPath"=>"$SPLUNK_DB/defaultdb/colddb", "blockSignSize"=>"0"}
    def read(field_list=nil)
      response = @service.context.get(@path)
      data = AtomResponseLoader::load_text(
        response, MATCH_ENTRY_CONTENT, NAMESPACES)
      _filter_content(data['content'], field_list)
    end

    # Return metadata information for this Entity. This is the same as:
    # <tt>entity.read(['eai:acl', 'eai:attributes')</tt>
    #
    # ==== Returns
    # A Hash of this entities attributes/values for 'eai:acl' and 'eai:attributes'
    #
    # ==== Example: Get metadata information for the index 'main'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.indexes['main'].readmeta
    #     {"eai:acl"=>{"app"=>"search", "can_list"=>"1",...},"eai:attributes"=>{"optionalFields"=>["assureUTF8"...]}}
    def readmeta
      read(['eai:acl', 'eai:attributes'])
    end

    # Updates an Entity with a Hash of attribute/value pairs specified as <b>+args+</b>
    #
    # ==== Returns
    # The Entity object after it's been updated
    #
    # ==== Example - Set the 'rotateValueInSecs' to 61 on index 'main'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   index =  svc.indexes['main']
    #   index.update('rotatePeriodInSecs' => '61')  #Note that you cannot use the number 61.  It must be a String.
    def update(args)
      @service.context.post(@path, args)
      self
    end

    def disable
      @service.context.post(@path + '/disable', '')
    end

    def enable
      @service.context.post(@path + '/enable', '')
    end

    def reload
      @service.context.post(@path + '/_reload', '')
    end
  end
end
