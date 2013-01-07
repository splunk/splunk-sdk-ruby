module Splunk
  class Service < Context

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
      response = request(:resource => PATH_CAPABILITIES)
      feed = AtomFeed.new(response.body)
      feed.entries[0]["content"]["capabilities"]
    end

    def confs
      Configurations.new(self)
    end

    def indexes
      Collection.new(self, PATH_INDEXES, entity_class=Index)
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
      response = request(:resource => PATH_INFO)
      feed = AtomFeed.new(response.body)
      feed.entries[0]["content"]
    end

    def jobs
      Jobs.new(self)
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
      Collection.new(self, PATH_LOGGER)
    end

    def messages
      Messages.new(self, PATH_MESSAGES, entity_class=Message)
    end

    def roles
      Collection.new(self, PATH_ROLES)
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

    def splunk_version
      info["version"].split(".").map() {|v| Integer(v)}
    end

    def users
      Collection.new(self, PATH_USERS)
    end
  end
end