require_relative "collection/configurations"

module Splunk

  class Context
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
      Collection.new(self, PATH_APPS_LOCAL)
    end

    def confs
      Configurations.new(self)
    end

    def jobs
      Jobs.new(self)
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
      Entity.new(self, namespace(), PATH_SETTINGS, "settings").refresh()
    end

    def users
      Collection.new(self, PATH_USERS)
    end
  end

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
      svc = Service.new(args)
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
      record = AtomResponseLoader::load_text_as_record(
        response, MATCH_ENTRY_CONTENT, NAMESPACES)
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
      item = Proc.new do |service, name|
        Entity.new(service, PATH_LOGGER + '/' + name, name)
      end
      Collection.new(self, PATH_LOGGER, 'loggers', :item => item)
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
      Entity.new(self, PATH_SETTINGS, 'settings')
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
      item = Proc.new{ |service, name| Index.new(service, name) }
      ctor = Proc.new do |service, name, args|
        new_args = args
        new_args[:name] = name
        service.context.post(PATH_INDEXES, new_args)
      end
      Collection.new(
        self, PATH_INDEXES, 'loggers', :item => item, :ctor => ctor)
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
      create_collection(PATH_ROLES, 'roles')
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
      create_collection(PATH_USERS, 'users')
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
    #       {
    #         "command": "search",
    #         "rawargs": "error",
    #         "pipeline": "streaming",
    #         "args": {
    #         "search": ["error"],
    #       }
    #       "isGenerating": true,
    #       "streamType": "SP_STREAM",
    #     },
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
      item = Proc.new{ |service, conf| ConfigurationFile.new(self, conf) }
      Collection.new(self, PATH_CONFS, 'confs', :item => item)
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
      item = Proc.new{ |service, name| Message.new(service, name) }
      ctor = Proc.new do |service, name, args|
        new_args = args
        new_args[:name] = name
        service.context.post(PATH_MESSAGES, new_args)
      end

      dtor = Proc.new do |service, name|
        service.context.delete(path + '/' + name)
      end

      Collection.new(
        self, PATH_MESSAGES, 'messages', :item => item, :ctor => ctor,
        :dtor => dtor)
    end

    def create_collection(path, collection_name=nil) # :nodoc:
      item = Proc.new do |service, name|
        Entity.new(service, path + '/' + name, name)
      end

      ctor = Proc.new do |service, name, args|
        new_args = args
        new_args[:name] = name
        service.context.post(path, new_args)
      end

      dtor = Proc.new do |service, name|
        service.context.delete(path + '/' + name)
      end
      Collection.new(
        self, path, collection_name, :item => item, :ctor => ctor,
        :dtor => dtor)
    end
  end
end
