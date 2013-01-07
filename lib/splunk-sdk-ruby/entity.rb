require_relative 'synonyms'

module Splunk
  # Entity objects represent individual items such as indexes, users, roles, etc.
  # They are usually contained within Collection objects
  class Entity
    extend Synonyms
    # The name of this Entity
    attr_reader :name

    # The namespace of this Entity
    attr_reader :namespace

    # The path of the collection this entity lives in
    attr_reader :resource

    # The service this entity refers to
    attr_reader :service

    def initialize(service, namespace, resource, name, state=nil) # :nodoc:
      @service = service
      @namespace = namespace
      @resource = resource
      @name = name
      @state = state
    end

    # Delete this entity.
    #
    def delete()
      @service.request({:method => :DELETE,
                        :namespace => @namespace,
                        :resource => @resource + [name]})
    end


    # Fetch the field _key_ on this entity.
    #
    # You may provide a default value. All values are returned
    # as strings.
    #
    def fetch(key, default=nil)
      @state["content"].fetch(key, default)
    end

    synonym "[]", "fetch"

    # Return a hash of the links associated with this entity.
    #
    def links()
      return @state["links"]
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
    def read(*field_list)
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
      read('eai:acl', 'eai:attributes')
    end

    # Refresh the cached state of this Entity.
    #
    # Returns the Entity.
    #
    def refresh()
      response = @service.request(:resource => @resource + [name],
                                  :namespace => @namespace)
      feed = AtomFeed.new(response.body)

      raise AmbiguousEntityReference.new("Found multiple entities matching" +
            " name and namespace.") if feed.entries.length > 1
      @state = feed.entries[0]
      self
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
      @service.request({:method => :POST,
                        :namespace => @namespace,
                        :resource => @resource + [name],
                        :body => args})
      self
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
      value
    end

    # Disable this entity.
    #
    # After a subsequent refresh, the "disabled" field will be set to "1".
    #
    def disable
      @service.request(:method => :POST,
                       :namespace => @namespace,
                       :resource => @resource + [name, "disable"])
    end

    # Enable this entity.
    #
    # After a subsequent refresh, the "disabled" field will be set to "0".
    #
    def enable
      @service.request(:method => :POST,
                       :namespace => @namespace,
                       :resource => @resource + [name, "enable"])
    end
  end
end
