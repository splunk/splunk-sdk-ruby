require "rubygems"
require "bundler/setup"

require_relative 'aloader'
require_relative 'context'
require 'libxml'
require 'cgi'
require 'json/pure' #TODO: Please get me working with json/ext - it SO much faster
require 'json/stream'

#I'm an idiot because I couldn't find any way to pass local context variables to
#a block in the parser.  Thus the hideous monkey-patch and the 'obj' param

class JSON::Stream::Parser
  def initialize(obj, &block)
    @state = :start_document
    @utf8 = JSON::Stream::Buffer.new
    @listeners = Hash.new {|h, k| h[k] = [] }
    @stack, @unicode, @buf, @pos = [], "", "", -1
    @obj = obj
    instance_eval(&block) if block_given?
  end
end


# :stopdoc:
def _filter_content(content, key_list=nil, add_attrs=true)
  if key_list.nil?
    return content.add_attrs if add_attrs
    return content
  end
  result = {}
  key_list.each {|key| result[key] = content[key]}

  return result.add_attrs if add_attrs
  result
end

def _path_stanza(conf, stanza)
  Splunk::PATH_STANZA % [conf, CGI::escape(stanza)]
end
# :startdoc:

module Splunk
  PATH_APPS_LOCAL = 'apps/local'
  PATH_CAPABILITIES = 'authorization/capabilities'
  PATH_LOGGER = 'server/logger'
  PATH_ROLES = 'authentication/roles'
  PATH_USERS = 'authentication/users'
  PATH_MESSAGES = 'messages'
  PATH_INFO = 'server/info'
  PATH_SETTINGS = 'server/settings'
  PATH_INDEXES = 'data/indexes'
  PATH_CONFS = "properties"
  PATH_CONF = "configs/conf-%s"
  PATH_STANZA = "configs/conf-%s/%s" #[file, stanza]
  PATH_JOBS = "search/jobs"
  PATH_EXPORT = "search/jobs/export"
  PATH_RESTART = "server/control/restart"
  PATH_PARSE = "search/parser"

  NAMESPACES = ['ns0:http://www.w3.org/2005/Atom', 'ns1:http://dev.splunk.com/ns/rest']
  MATCH_ENTRY_CONTENT = '/ns0:feed/ns0:entry/ns0:content'



  ##
  # The <b>Client Layer</b><br>.
  # This class is the main place for clients to access and control Splunk.
  # You create a Service instance by simply calling Service::connect or
  # just creating a new Service instance with your user and password.
  #
  class Service
    attr_reader :context # :nodoc:

    # Create an instance of Service and logs in to Splunk
    #
    # ==== Attributes
    # +args+ - Valid args are listed below.  Note that they are all Strings:
    # * +:username+ - log in to Splunk as this user (no default)
    # * +:password+ - password for user 'username' (no default)
    # * +:host+ - Splunk host (e.g. '10.1.2.3') (defaults to 'localhost')
    # * +:port+ - the Splunk management port (defaults to '8089')
    # * +:protocol+ - either 'https' or 'http' (defaults to 'https')
    # * +:namespace+ - application namespace option.  'username:appname' (defaults to nil)
    # * +:key_file+ - the full path to a SSL key file (defaults to nil)
    # * +:cert_file+ - the full path to a SSL certificate file (defaults to nil)
    #
    # ==== Returns
    # instance of a Service class - must call login to use
    #
    # ==== Examples
    #   svc = Splunk::Service.new(:username => 'admin', :password => 'foo')
    #   svc = Splunk::Service.new(:username => 'admin', :password => 'foo', :host => '10.1.1.1', :port = '9999')
    def initialize(args)
      @context = Context.new(args)
    end

    # Creates an instance of Service and logs into Splunk
    #
    # ==== Attributes
    # +args+ - Same as ::new
    #
    # ==== Returns
    # instance of a Service class, logged into Splunk
    #
    # ==== Examples
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.apps #get a list of apps (we can do this because we are logged in)
    def self.connect(args)
      svc = Service.new args
      svc.login
      svc
    end

    # Log into Splunk
    #
    # ==== Examples
    #   svc = Splunk::Service.new(:username => 'admin', :password => 'foo')
    #   svc.login #Now we can make other calls to Splunk via svc
    #
    def login
      @context.login
    end

    # Log out of Splunk
    def logout
      @context.logout
    end

    # Return a collection of all apps.  To operate on apps, call methods on the returned Collection
    # and Entities from the Collection.
    #
    # ==== Returns
    # Collection of all apps
    #
    # ==== Example 1 - list all apps
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.apps.each {|app| puts app['name']}
    #     gettingstarted
    #     launcher
    #     learned
    #     legacy
    #     sample_app
    #     search
    #     splunk_datapreview
    #     ...
    #
    # ==== Example 2 - delete the sample app
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.apps.delete('sample_app')
    #
    # ==== Example 3 - display permissions for the sample app
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   sapp = svc.apps['sample_app']
    #   puts sapp['eai:acl']['perms']
    #     {"read"=>["*"], "write"=>["*"]}
    def apps
      create_collection(PATH_APPS_LOCAL)
    end

    # Return the list of all capabilities in the system.  This list is not mutable because capabilities
    # are hard-wired into Splunk
    #
    # ==== Returns
    # An Array of capability Strings
    #
    # ==== Examples
    #   svc = Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.capabilities
    #     ["admin_all_objects", "change_authentication", "change_own_password", "delete_by_keyword",...]
    def capabilities
      response = @context.get(PATH_CAPABILITIES)
      record = AtomResponseLoader::load_text_as_record(response, MATCH_ENTRY_CONTENT, NAMESPACES)
      record.content.capabilities
    end

    # Returns a ton of info about the running Splunk instance
    #
    # ==== Returns
    # A Hash of key/value pairs
    #
    # ==== Examples
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.info
    #     {"build"=>"112383", "cpu_arch"=>"i386", "eai:acl"=>{"app"=>nil, "can_list"=>"0",......}
    def info
      response = @context.get(PATH_INFO)
      record = AtomResponseLoader::load_text_as_record(response, MATCH_ENTRY_CONTENT, NAMESPACES)
      record.content
    end

    # Returns all loggers in the system.  Each logger logs errors, warnings, debug info, or informational
    # information about a specific part of the Splunk system
    #
    # ==== Returns
    # A Collection of loggers
    #
    # ==== Example - display each logger along with it's minimum log level (ERROR, WARN, INFO, DEBUG)
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.loggers.each {|logger| puts logger.name + ":" + logger['level']}
    #     ...
    #     DedupProcessor:WARN
    #     DeployedApplication:INFO
    #     DeployedServerClass:WARN
    #     DeploymentClient:WARN
    #     DeploymentClientAdminHandler:WARN
    #     DeploymentMetrics:INFO
    #     ...
    def loggers
      item = Proc.new {|service, name| Entity.new(service, PATH_LOGGER + '/' + name, name)}
      Collection.new(self, PATH_LOGGER, "loggers", :item => item)
    end

    # Returns Splunk server settings
    #
    # ==== Returns
    # An Entity with all server settings
    #
    # ==== Example - get a Hash of all server settings
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.settings.read
    #     {"SPLUNK_DB"=>"/opt/4.3/splunkbeta/var/lib/splunk", "SPLUNK_HOME"=>"/opt/4.3/splunkbeta",...}
    def settings
      Entity.new(self, PATH_SETTINGS, "settings")
    end

    # Returns all indexes
    #
    # ==== Returns
    # A Collection of Index objects
    #
    # ==== Example 1 - display the name of all indexes along with various attributes of each
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.indexes.each do |i|
    #     puts i.name + ': ' + String(i.read(['maxTotalDataSizeMB', 'frozenTimePeriodInSecs']))
    #   end
    #
    #     _audit: {"maxTotalDataSizeMB"=>"500000", "frozenTimePeriodInSecs"=>"188697600"}
    #     _blocksignature: {"maxTotalDataSizeMB"=>"0", "frozenTimePeriodInSecs"=>"0"}
    #     _internal: {"maxTotalDataSizeMB"=>"500000", "frozenTimePeriodInSecs"=>"2419200"}
    #     _thefishbucket: {"maxTotalDataSizeMB"=>"500000", "frozenTimePeriodInSecs"=>"2419200"}
    #     history: {"maxTotalDataSizeMB"=>"500000", "frozenTimePeriodInSecs"=>"604800"}
    #     ...
    #
    # ==== Example 2 - clean (removed all data from) the index 'main'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   main = svc.indexes['main'] #Return Entity object for index 'main'
    #   main.clean
    def indexes
      item = Proc.new {|service, name| Index.new(service, name)}
      ctor = Proc.new { |service, name, args|
        new_args = args
        new_args[:name] = name
        service.context.post(PATH_INDEXES, new_args)
      }
      Collection.new(self, PATH_INDEXES, "loggers", :item => item, :ctor => ctor)
    end

    # Returns all roles
    #
    # ==== Returns
    # A Collection of roles
    #
    # ==== Example - List every role along with it's list of capabilities
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.roles.each {|i| puts i.name + ': ' + String(i.read.capabilities) }
    #     admin: ["admin_all_objects", "change_authentication", ... ]
    #     can_delete: ["delete_by_keyword"]
    #     power: ["rtsearch", "schedule_search"]
    #     user: ["change_own_password", "get_metadata", ... ]
    def roles
      create_collection(PATH_ROLES, "roles")
    end

    # Returns all users
    #
    # ==== Returns
    # A Collection of users
    #
    # ==== Example - Create a new user, then list all users
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.users.create('jack', :password => 'mypassword', :realname => 'Jack_be_nimble', :roles => ['user'])
    #   svc.users.each {|i| puts i.name + ':' + String(i.read) }
    #     admin:{"defaultApp"=>"launcher", "defaultAppIsUserOverride"=>"1", "defaultAppSourceRole"=>"system",
    #     jack:{"defaultApp"=>"launcher", "defaultAppIsUserOverride"=>"0", "defaultAppSourceRole"=>"system",
    def users
      create_collection(PATH_USERS, "users")
    end

    # Returns a new Jobs object
    #
    # ==== Returns
    # A new Jobs object
    #
    # ==== Example - Display the disk usage of all jobs
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   jobs = svc.jobs.list
    #   jobs.each {|job| puts job['diskUsage'] }
    #     177445
    #     489999
    def jobs
      Jobs.new(self)
    end

    # Restart the Splunk Server
    #
    # ==== Returns
    #   A bunch of crappy XML that makes little sense
    def restart
      @context.get(PATH_RESTART)
    end

    # Parse a search into it's components
    #
    # ==== Returns
    # A JSON structure with information about the search
    #
    # ==== Example - Parse a simple search
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.parse("search error")
    #     {
    #       "remoteSearch": "litsearch error | fields  keepcolorder=t \"host\" \"index\" \"linecount\" \"source\" \"sourcetype\" \"splunk_server\"",
    #       "remoteTimeOrdered": true,
    #       "eventsSearch": "search error",
    #       "eventsTimeOrdered": true,
    #       "eventsStreaming": true,
    #       "reportsSearch": "",
    #       "commands": [
    #     	{
    #     		"command": "search",
    #     		"rawargs": "error",
    #     		"pipeline": "streaming",
    #     		"args": {
    #   			"search": ["error"],
    #   		}
    #   		"isGenerating": true,
    #   		"streamType": "SP_STREAM",
    #   	},
    #     ]
    #     }
    def parse(query, args={})
      args['q'] = query
      args['output_mode'] = 'json'
      @context.get(PATH_PARSE, args)
    end

    # Return a Collection of ConfCollection objects.  Each ConfCollection represents a Collection of
    # stanzas in that particular configuration file.
    #
    # ==== Returns
    # A Collection of ConfCollection objects
    #
    # ==== Notes
    # You cannot use dot (.) notation for accessing configs, stanzas or lines beacause
    # they can look nasty, thus breaking Ruby's idea of an accessor
    #
    # ==== Example 1 - Display a list of stanzas in the props.conf file
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts s.confs['props'].list
    #     (?i)source::....zip(.\d+)?
    #     __singleline
    #     access_combined
    #     access_combined_wcookie
    #     access_common
    #     ActiveDirectory
    #     anaconda
    #     ...
    #
    # ==== Example 2 - Display a Hash of configuration lines on a particular stanza
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   confs = svc.confs             #Return a Collection of ConfCollection objects (config files)
    #   stanzas = confs['props']      #Return a ConfCollection (stanzas in a config file)
    #   stanza = stanzas['manpage']   #Return a Conf Object (lines in a stanza)
    #   puts stanza.read
    #     {"ANNOTATE_PUNCT"=>"1", "BREAK_ONLY_BEFORE"=>"gooblygook", "BREAK_ONLY_BEFORE_DATE"=>"1",...}
    def confs
      item = Proc.new {|service, conf| ConfCollection.new(self, conf) }
      Collection.new(self, PATH_CONFS, "confs", :item => item)
    end

    # Return a collection of Message objects
    #
    # ==== Returns
    # A Collection of Message objects
    #
    # ==== Example 1 - list all message names
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.messages.list
    #     test
    #
    # ==== Example 2 - display the message named 'test'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts s.messages['test'].value
    #     my message
    def messages
      item = Proc.new {|service, name| Message.new(service, name)}
      ctor = Proc.new { |service, name, args|
        new_args = args
        new_args[:name] = name
        service.context.post(PATH_MESSAGES, new_args)
      }

      dtor = Proc.new { |service, name| service.context.delete(path + '/' + name) }
      Collection.new(self, PATH_MESSAGES, "messages", :item => item, :ctor => ctor, :dtor => dtor)
    end

    def create_collection(path, collection_name=nil) # :nodoc:
      item = Proc.new { |service, name| Entity.new(service, path + '/' + name, name) }

      ctor = Proc.new { |service, name, args|
        new_args = args
        new_args[:name] = name
        service.context.post(path, new_args)
      }

      dtor = Proc.new { |service, name| service.context.delete(path + '/' + name) }
      Collection.new(self, path, collection_name, :item => item, :ctor => ctor, :dtor => dtor)
    end
  end


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
      response = @service.context.get(@path + "?count=-1")
      record = AtomResponseLoader::load_text_as_record(response)
      return retval if !record.feed.instance_variable_defined?('@entry')
      if record.feed.entry.is_a?(Array)
        record.feed.entry.each do |entry|
          retval << entry["title"] #because 'entry' is an array we don't allow dots
        end
      else
        retval << record.feed.entry.title
      end
      retval
    end
  end

  # Entity objects represent individual items such as indexes, users, roles, etc.
  # They are usually contained within Collection objects
  class Entity
    # The name of this Entity
    attr_reader :name

    def initialize(service, path, name=nil) # :nodoc:
      @service = service
      @path = path
      @name = name
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
      #obj.send(key)
      return obj[key]
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
      data = AtomResponseLoader::load_text(response, MATCH_ENTRY_CONTENT, NAMESPACES)
      _filter_content(data["content"], field_list)
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
    def readmeta()
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
      @service.context.post(@path + "/disable", '')
    end

    def enable
      @service.context.post(@path + "/enable", '')
    end

    def reload
      @service.context.post(@path + "/_reload", '')
    end

  end

  # Message objects represent system-wide messages
  class Message < Entity
    def initialize(service, name)
      super(service, PATH_MESSAGES + '/' + name, name)
    end

    # Return the message
    #
    # ==== Returns
    # The message String: (the value of the message named <b>+name+</b>)
    def value
      self[@name]
    end
  end

  # Splunk can have many indexes.  Each index is represented by an Index object.
  class Index < Entity
    def initialize(service, name)
      super(service, PATH_INDEXES + '/' + name, name)
    end

    # Streaming HTTP(S) input for Splunk. Write to the returned stream Socket, and Splunk will index the data.
    # Optionally, you can assign a <b>+host+</b>, <b>+source+</b> or <b>+sourcetype+</b> that will apply
    # to every event sent on the socket. Note that the client is responsible for closing the socket when finished.
    #
    # ==== Returns
    # Either an encrypted or non-encrypted stream Socket depending on if Service.connect is http or https
    #
    # ==== Example - Index 5 events written to the stream and assign a sourcetype 'mysourcetype' to each event
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   stream = svc.indexes['main'].attach(nil, nil, 'mysourcetype')
    #   (1..5).each { stream.write("This is a cheezy event\r\n") }
    #   stream.close
    def attach(host=nil, source=nil, sourcetype=nil)
      args = {:index => @name}
      args['host'] = host if host
      args['source'] = source if source
      args['sourcetype'] = sourcetype if sourcetype
      path = "receivers/stream?#{args.urlencode}"

      cn = @service.context.connect
      cn.write("POST #{@service.context.fullpath(path)} HTTP/1.1\r\n")
      cn.write("Host: #{@service.context.host}:#{@service.context.port}\r\n")
      cn.write("Accept-Encoding: identity\r\n")
      cn.write("Authorization: Splunk #{@service.context.token}\r\n")
      cn.write("X-Splunk-Input-Mode: Streaming\r\n")
      cn.write("\r\n")
      cn
    end

    # Nuke all events in this index.  This is done by setting <b>+maxTotalDataSizeMG+</b> and
    # <b>+frozenTimePeriodInSecs+</b> both to 1. The call will then block until <b>+totalEventCount+</b> == 0.
    # When the call is completed, the original parameters are restored.
    #
    # ==== Returns
    # The original 'maxTotalDataSizeMB' and 'frozenTimePeriodInSecs' parameters in a Hash
    #
    # ==== Example - clean the 'main' index
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.indexes['main'].clean
    def clean
      saved = read(['maxTotalDataSizeMB', 'frozenTimePeriodInSecs'])
      update(:maxTotalDataSizeMB => 1, :frozenTimePeriodInSecs => 1)
      #@service.context.post(@path, {})
      until self['totalEventCount'] == '0' do
        sleep(1)
        puts self['totalEventCount']
      end
      update(saved)
    end

    # Batch HTTP(S) input for Splunk. Specify one or more events in a String along with optional
    # <b>+host+</b>, <b>+source+</b> or <b>+sourcetype+</b> fields which will apply to all events.
    #
    # Example - Index a single event into the 'main' index with source 'baz' and sourcetype 'foo'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.indexes['main'].submit("this is an event", nil, "baz", "foo")
    #
    # Example 2 - Index multiple events into the 'main' index with default metadata
    # TODO: Fill me in
    def submit(events, host=nil, source=nil, sourcetype=nil)
      args = {:index => @name}
      args['host'] = host if host
      args['source'] = source if source
      args['sourcetype'] = sourcetype if sourcetype

      path = "receivers/simple?#{args.urlencode}"
      @service.context.post(path, events, {})
    end

    # Upload a file accessible by the Splunk server.  The full path of the file is specified by
    # <b>+filename+</b>.
    #
    # ==== Optional Arguments
    # +args+ - Valid optional args are listed below.  Note that they are all Strings:
    # * +:host+ - The host for the events
    # * +:host_regex+ - A regex to be used to extract a 'host' field from the path.
    #   If the path matches this regular expression, the captured value is used to populate the 'host' field
    #   or events from this data input.  The regular expression must have one capture group.
    # * +:host_segment+ - Use the specified slash-seperated segment of the path as the host field value.
    # * +:rename-source+ - The value of the 'source' field to be applied to the data from this file
    # * +:sourcetype+ - The value of the 'sourcetype' field to be applied to data from this file
    #
    # ==== Example - Upload a file using defaults
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.indexes['main'].upload("/Users/rdas/myfile.log")
    def upload(filename, args={})
      args['index'] = @name
      args['name'] = filename
      path = "data/inputs/oneshot"
      @service.context.post(path, args)
    end
  end


  class Conf < Entity
    def initialize(service, path, name)
      super(service, path, name)
    end
    # ==== Example 2 - Display a Hash of configuration lines on a particular stanza
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   confs = svc.confs             #Return a Collection of ConfCollection objects (config files)
    #   stanzas = confs['props']      #Return a ConfCollection (stanzas in a config file)
    #   stanza = stanzas['manpage']   #Return a Conf object (lines in a stanza)
    #   puts stanza.read
    #     {"ANNOTATE_PUNCT"=>"1", "BREAK_ONLY_BEFORE"=>"gooblygook", "BREAK_ONLY_BEFORE_DATE"=>"1",...}
    def read(field_list=nil)
      response = @service.context.get(@path)
      data = AtomResponseLoader::load_text(response, MATCH_ENTRY_CONTENT, NAMESPACES)
      _filter_content(data["content"], field_list, false)
    end

    #Populate a stanza in the .conf file
    def submit(stanza)
      @service.context.post(@path, stanza, {})
    end
  end

  # A Collection of Conf objects
  class ConfCollection < Collection
    def initialize(svc, conf)
      item = Proc.new {|service, stanza| Conf.new(service, _path_stanza(conf, stanza), stanza)}
      ctor = Proc.new {|service, stanza, args|
            new_args = args
            new_args[:name] = stanza
            service.context.post(PATH_CONF % conf, new_args)
          }
      dtor = Proc.new {|service, stanza| service.context.delete(_path_stanza(conf, stanza))}
      super(svc, PATH_CONF % [conf, conf], conf, :item => item, :ctor => ctor, :dtor => dtor)
    end
  end

  # Jobs objects are used for executing searches and retrieving a list of all jobs
  class Jobs < Collection
    def initialize(svc)
      @service = svc
      item = Proc.new {|service, sid| Job.new(service, sid)}
      super(svc, PATH_JOBS, "jobs", :item => item)
    end

    # Run a search.  This search can be either synchronous (oneshot) or asynchronous.  A synchronous search
    # will execute the search and the caller will block until the results have been returned.  An asynchronous search
    # will return immediately, returning a Job object that can be queried for completion, paused, etc.
    # There are many possible arguments - all are documented in the Splunk REST documentation at
    # http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs - POST.  The one that controls
    # either synchronous or asynchronous is called <b>+:exec_mode+</b>.
    #
    # ==== Example 1 - Execute a synchronous search returning XML (XML is the default output mode )
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.jobs.create("search error", :max_count => 10, :max_results => 10, :exec_mode => 'oneshot')
    #
    # ==== Example 2 - Execute a synchronous search returning results in JSON
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.jobs.create("search error", :max_count => 10, :max_results => 10, :exec_mode => 'oneshot', :output_mode => 'json')
    #
    # ==== Example 3 - Execute a synchronous search returning a Job object with the results as a JSON String
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   job = svc.jobs.create("search error", :max_count => 10, :max_results => 10, :exec_mode => 'blocking')
    #   puts job.results(:output_mode => 'json')
    #
    # ==== Example 4 - Execute an asynchronous search and wait for all the results (returned in JSON)
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   job = svc.jobs.create("search error", :max_count => 10, :max_results => 10)
    #   while true
    #     stats = job.read(['isDone'])
    #     break if stats['isDone'] == '1'
    #     sleep(1)
    #   end
    #   puts job.results(:output_mode => 'json')
    def create(query, args={})
      args["search"] = query
      response = @service.context.post(PATH_JOBS, args)

      return response if args[:exec_mode] == 'oneshot'

      response = AtomResponseLoader::load_text(response)
      sid = response['response']['sid']
      Job.new(@service, sid)
    end

    #Convenience method that runs a synchronous search returning an enumerable SearchResults object. This
    #object allows you to iterate through each individual event.
    #You can use any arguments from the REST call (specfied in Jobs.create) you wish,
    #but ':exec_mode' and ':output_mode' will always be set to 'oneshot' and 'json' respectively.
    #
    #==== Example - Execute a search and show just the raw events followed by the event count
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   results = svc.jobs.create_oneshot("search error", :max_count => 10, :max_results => 10)
    #   results.each {|event| puts event['_raw']}
    #   puts results.count
    def create_oneshot(query, args={})
      args[:search] = query
      args[:exec_mode] = "oneshot"
      args[:output_mode] = "json"
      response = @service.context.post(PATH_JOBS, args)

      json = JSON.parse(response)
      SearchResults.new(json)
    end

    # Run a <b>streamed search</b> .  Rather than returning an object that can take up a huge amount of memory by including
    # large numbers of search results, a streamed search buffers only a chunk at a time and provides an interface
    # that the client can use to retrieve results without taking up any more memory than just for the buffer itself.
    # The arguments are exactly the same as for the other search methods in this class except that <b>+:output_mode+</b>
    # will always be 'json' because results are always in JSON.
    #
    # Returns a Splunk::ResultsReader object
    #
    # ==== Example 1 - Simple streamed search
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   reader = svc.jobs.create_stream('search host="45.2.94.5" | timechart count')
    #   reader.each {|event| puts event}
    #
    # ==== Example 2 - Real time streamed search
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   reader = svc.jobs.create_stream('search index=_internal',\
    #   :search_mode => 'realtime', :earliest_time => 'rt-1m', :latest_time => 'rt')
    #   reader.each {|event| puts event} #will block until events show up in real-time
    def create_stream(query, args={})
      args[:search] = query
      args[:output_mode] = "json"

      path = PATH_JOBS + "/export?#{args.urlencode}"

      cn = @service.context.connect
      cn.write("GET #{@service.context.fullpath(path)} HTTP/1.1\r\n")
      cn.write("Host: #{@service.context.host}:#{@service.context.port}\r\n")
      cn.write("User-Agent: splunk-sdk-ruby/0.1\r\n")
      cn.write("Authorization: Splunk #{@service.context.token}\r\n")
      cn.write("Accept: */*\r\n")
      cn.write("\r\n")

      cn.readline #return code TODO: Parse me and return error if problem
      cn.readline #accepts
      cn.readline #blank

      ResultsReader.new(cn)
    end

    # Return an Array of Jobs
    #
    # ==== Example - Display the disk usage of each job
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.jobs.list.each {|job| puts job['diskUsage'] }
    def list
      response = @service.context.get(PATH_JOBS)
      entry = AtomResponseLoader::load_text_as_record(response, MATCH_ENTRY_CONTENT, NAMESPACES)
      return [] if entry.nil?
      entry = [entry] if !entry.is_a? Array
      retarr = []
      entry.each { |item| retarr << Job.new(@service, item.content.sid) }
      retarr
    end
  end

  class Job
    def initialize(svc, sid)
      @service = svc
      @sid = sid
      @path = PATH_JOBS + '/' + sid
      @control_path = @path + '/control'
    end
    # Access an individual attribute named <b>+key+</b> about this job.
    # Note that this results in an HTTP round trip, fetching all values for the Job even though a single
    # attribute is returned.
    #
    # ==== Returns
    # A String representing the attribute fetched
    #
    # ==== Example - Display the disk usage of each job
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.jobs.list.each {|job| puts job['diskUsage'] }
    def [](key)
      obj = read([key])
      return obj[key]
    end

    # Return all or a specified subset of attribute/value pairs for this Job
    #
    # ==== Returns
    # A Hash of all attributes and values for this Job.  If Array <b>+field_list+</b> is specified,
    # only those fields are returned.  If a field does not exist, nil is returned for it's value.
    #
    # ==== Example - Return a Hash of all attribute/values for a list of Job
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.jobs.list.each do |job|
    #     dataHash = job.read
    #   end
    def read(field_list=nil)
      response = @service.context.get(@path)
      data = AtomResponseLoader::load_text(response)
      _filter_content(data["entry"]["content"], field_list)
    end

    # Cancel this search job.  Stops the search and deletes the results cache.
    def cancel
      @service.context.post(@control_path, :action => 'cancel')
      self
    end

    # Disable preview generation for this job
    def disable_preview
      @service.context.post(@control_path, :action => 'disablepreview')
      self
    end

    # Returns the events of this search job.
    # These events are the data from the search pipeline before the first "transforming" search command.
    # This is the primary method for a client to fetch a set of UNTRANSFORMED events for this job.
    # This call is only valid if the search has no transforming commands. Set <b>+:output_mode+</b> to 'json' if you
    # want results in JSON.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fevents]
    # for more info on valid parameters and results.
    def events(args={})
      @service.context.get(@path + '/events', args)
    end

    # Enable preview generation for this job.  This may slow the search down considerably.
    def enable_preview
      @service.context.post(@control_path, :action => 'enablepreview')
      self
    end

    # Finalize this search job. Stops the search and provides intermediate results
    # (retrievable via Job::results)
    def finalize
      @service.context.post(@control_path, :action => 'finalize')
      self
    end

    # Suspend this search job.
    def pause
      @service.context.post(@control_path, :action => 'pause')
      self
    end

    # Generate a preview for this search Job.  Results are always in JSON.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fresults_preview]
    # for more info on valid parameters and results.
    def preview(args={})
      @service.context.get(@path + '/results_preview', args)
    end

    # Returns the current results of the search for this job.  This is the table that exists after all processing
    # from the search pipeline has completed.  This is the primary method for a client to fetch a set of
    # TRANSFORMED events.  If the dispatched search doesn't include a transforming command, the effect is the same
    # as Job::events.   Set <b>+:output_mode+</b> to 'json' if you
    # want results in JSON.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fresults]
    # for more info on valid parameters and results.

    # ==== Example 1 - Execute a blocking (synchronous) search returning the results
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   job = svc.jobs.create("search error", :max_count => 10, :max_results => 10, :exec_mode => 'blocking')
    #   puts job.results(:output_mode => 'json')
    #
    # ==== Example 2 - Execute an asynchronous search and wait for all the results
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   job = svc.jobs.create("search error", :max_count => 10, :max_results => 10)
    #   while true
    #     stats = job.read(['isDone'])
    #     break if stats['isDone'] == '1'
    #     sleep(1)
    #   end
    #   puts job.results(:output_mode => 'json')
    def results(args={})
      args[:output_mode] = 'json'
      @service.context.get(@path + '/results', args)
    end

    # Returns the search.log for this search Job.  Only a few lines of the search log are returned.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fsearch.log]
    # for more info on valid parameters and results.
    def searchlog(args={})
      @service.context.get(@path + 'search.log', args)
    end

    # Sets the priority of this search Job.  <b>+value+</b> can be 0-10.
    def setpriority(value)
      @service.context.post(@control_path, :action => 'setpriority', :priority => value)
      self
    end

    # Returns field summary information that is usually used to populate the fields picker
    # in the default search view in the Splunk GUI. Note that results are ONLY available in XML.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fsummary]
    # for more info on valid parameters and results.
    def summary(args={})
      @service.context.get(@path + '/summary', args)
    end

    # Returns event distribution over time of the so-far-read untransformed events.  Results are ONLY
    # available in XML.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Ftimeline]
    # for more info on valid parameters and results.
    def timeline(args={})
      @service.context.get(@path + 'timeline', args)
    end

    # Extends the expiration time of the search for this Job to now + ttl (see Job::setttl for setting the ttl)
    def touch
      @service.context.post(@control_path, :action => 'touch')
      self
    end

    # Set the time-to-live (ttl) of the search for this Job. <b>+value+</b> is a number
    def setttl(value)
      @service.context.post(@control_path, :action => 'setttl', :ttl => value)
    end

    # Resumes execution of the search for this Job.
    def unpause
      @service.context.post(@control_path, :action => 'unpause')
      self
    end
  end

  class SearchResults
    include Enumerable

    def initialize(data)
      @data = data
    end

    def each(&block)
      @data.each {|row| block.call(row) }
    end
  end

  # This class allows clients to enumerate events that are the results of a streaming search via the
  # Splunk::Jobs::create_stream call.  This enumeration is done in a 'chunked' way - that is the results
  # are not all streamed into a large in-memory JSON data structure, but pulled as ResultsReader::each is called.
  class ResultsReader
    include Enumerable

    def initialize(socket)
      @socket = socket
      @events = []

      callbacks = proc do
        start_document {
          #puts 'start document'
          @array_depth = 0
        }

        end_document {
          #puts 'end document'
        }

        start_object {
          @event = {}
        }
        end_object {
          @obj.event_found(@event)
        }

        start_array {
          #puts 'start array'
          @array_depth += 1
          if @array_depth > 1
            @isarray = true
            @array = []
          end
        }

        end_array {
          if @array_depth > 1
            @event[@k] = @array
            @isarray = false
          end
          #puts 'end array'
        }

        key {|k|
          @k = k
        }

        value {|v|
          if @isarray
            @array << v
          else
            @event[@k] = v
          end
        }
      end

      @parser = JSON::Stream::Parser.new(self, &callbacks)
    end

    def close # :nodoc:
      @socket.close()
    end

    def event_found(event) # :nodoc:
      @events << event
    end

    def read # :nodoc:
      data = @socket.read(4096)
      return nil if data.nil?
      #TODO: Put me in to show [] at end of events bug
      #puts String(data.size) + ':' + data
      @parser << data
      data.size
    end

    # Calls block once for each returned event
    #
    # ==== Example 1 - Simple streamed search
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   reader = svc.jobs.create_stream('search host="45.2.94.5" | timechart count')
    #   reader.each {|event| puts event}
    def each(&block)  # :yields: event
      while true
        sz = read if @events.count == 0
        break if sz == 0 or sz.nil?
        @events.each do |event|
          block.call(event)
        end
        @events.clear
      end
      close
    end
  end
end

=begin

s = Splunk::Service::connect(:username => 'admin', :password => 'password')

p s.apps.list

p "Testing read...."
s.apps.each do |app|
  x = app.read()
  p x.check_for_updates
end

p "Testing readmeta...."
s.apps.each do |app|
  x = app.readmeta()
  p x.eai_acl.can_write
end

p "Testing []........"
s.apps.each do |app|
  p app['check_for_updates']
end

p "Testing capabilities......"
p s.capabilities

p "Testing info....."
p s.info.version

p "Testing loggers......"
s.loggers.each do |logger|
  p logger.read()
end

p "Testing settings....."
p s.settings

p "Testing users......"
p s.users.list
s.users.each do |user|
  u = user.read()
  p user.name
  p u.realname
end

p "Testing roles......."
p s.roles.list

p "Testing messages......"
#p s.messages.list


#TODO: Need to test updating & messages (need some messages)


p "Testing indexes"
s.indexes.each do |index|
  p index.name
  p index.read(['maxTotalDataSizeMB', 'frozenTimePeriodInSecs'])
end


main = s.indexes['main']
main.clean

#main.submit("this is an event", nil, "baz", "foo")

#main.upload("/Users/rdas/logs/xaa")

cn = main.attach()
(1..5).each do
  cn.write("Hello World\r\n")
end
cn.close


p s.indexes
p s.indexes['main'].read

s.confs.each do |conf|
  conf.each do |stanza|
    stanza.read
    break
  end
end


props = s.confs['props']
stanza = props.create('sdk-tests')
p props.contains? 'sdk-tests'
p stanza.name
p stanza.read().keys.include? 'maxDist'
p stanza.read()['maxDist']
value = Integer(stanza['maxDist'])
p 'value=%d' % value
stanza.update(:maxDist => value+1)
p 'value after=%d' % stanza['maxDist']
props.delete('sdk-tests')
p props.contains? 'sdk-tests'

=end
#s = Splunk::Service::connect(:username => 'admin', :password => 'password')

#reader = s.jobs.create_stream('search host="45.2.94.5" | timechart count')
#reader.each {|event| puts event}

#index =  s.indexes['main']
#puts index.update('rotatePeriodInSecs' => '61')


#puts s.confs['props'].list
#puts s.messages['test'].value

#puts s.confs['props']['manpage'].read
#job = s.jobs.create("search * | stats count", :max_count => 1000, :max_results => 1000, :oneshot => true)

#p s.settings.read
#s.loggers.each {|logger| puts logger.name + ":" + logger['level']}

#reader.close

#job = s.jobs.create("search error", :max_count => 10, :max_results => 10)
#while true
# stats = job.read(['isDone'])
# break if stats['isDone'] == '1'
# sleep(1)
#end
#
#puts job.results(:output_mode => 'json')

#result = jobs.create("search *", :exec_mode => 'oneshot', :output_mode => 'json')
#puts '********************************'
#puts result

#result = jobs.create_oneshot("search *", :max_count => 1000, :max_results => 1000)
#result.each {|row| puts row['_raw']}
#puts result.count

#s.jobs.list.each {|job| puts job['diskUsage'] }
