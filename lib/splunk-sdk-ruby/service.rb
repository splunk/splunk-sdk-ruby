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

require_relative 'atomfeed'
require_relative 'collection'
require_relative 'collection/apps'
require_relative 'collection/configurations'
require_relative 'collection/input_kinds'
require_relative 'collection/jobs'
require_relative 'collection/messages'
require_relative 'collection/case_insensitive_collection'
require_relative 'context'
require_relative 'entity'
require_relative 'entity/index'
require_relative 'entity/job'
require_relative 'entity/message'
require_relative 'entity/modular_input_kind'
require_relative 'entity/saved_search'
require_relative 'entity/stanza'

##
# This module provides the +Service+ class, which encapsulates the interaction
# with Splunk.
#

module Splunk
  # The paths used by service.
  PATH_APPS_LOCAL = ["apps", "local"]
  PATH_CAPABILITIES = ["authorization", "capabilities"]
  PATH_LOGGER = ["server","logger"]
  PATH_ROLES = ["authorization", "roles"]
  PATH_USERS = ["authentication","users"]
  PATH_MESSAGES = ["messages"]
  PATH_MODULAR_INPUT_KINDS = ["data", "modular-inputs"]
  PATH_INFO = ["server", "info"]
  PATH_INPUTS = ["data", "inputs"]
  PATH_SETTINGS = ["server", "settings"]
  PATH_INDEXES = ["data","indexes"]
  PATH_CONFS = ["properties"]
  PATH_CONF = ["configs"]
  PATH_SAVED_SEARCHES = ["saved", "searches"]
  PATH_STANZA = ["configs","conf-%s","%s"]
  PATH_JOBS = ["search", "jobs"]
  PATH_EXPORT = ["search", "jobs", "export"]

  ##
  # Create a logged in reference to a Splunk instance.
  #
  # +connect+ takes a hash of values as its sole argument. The keys it
  # understands are:
  #
  # * `:username` - log in to Splunk as this user (no default)
  # * `:password` - password to use when logging in (no default)
  # * `:host` - Splunk host (e.g. "10.1.2.3") (defaults to 'localhost')
  # * `:port` - the Splunk management port (defaults to '8089')
  # * `:protocol` - either 'https' or 'http' (defaults to 'https')
  # * `:namespace` - application namespace option.  'username:appname'
  #     (defaults to nil)
  # * `:token` - a preauthenticated Splunk token (default to nil)
  #
  # Returns: a logged in +Service+ object.
  #
  # *Example:*
  #
  #     require 'splunk-sdk-ruby'
  #     service = Splunk::connect(:username => "admin", :password => "changeme")
  #
  def self.connect(args)
    Service.new(args).login()
  end

  ##
  # A user friendly interface to the Splunk REST API.
  #
  # +Service+ subclasses +Context+ (which provides the methods to login to
  # Splunk and make requests to the REST API), and adds convenience methods
  # for accessing the major collections of entities, such as indexes,
  # search jobs, and configurations.
  #
  class Service < Context
    ##
    # Returns a collection of all the apps installed on Splunk.
    #
    # Returns a +Collection+ containing +Entity+ objects.
    #
    # *Examples:*:
    #
    #     require 'splunk-sdk-ruby'
    #     service = Splunk::connect(:username => 'admin', 
    #                               :password => 'changeme')
    #     service.apps.each do |app|
    #       puts app.name
    #     end
    #
    def apps
      Apps.new(self, PATH_APPS_LOCAL)
    end

    ##
    # Returns an +Array+ of all the capabilities roles may have in Splunk.
    #
    # Capabilities are a fixed list on the server, so this method returns
    # an +Array+ rather than an +Entity+.
    #
    # Returns: an +Array+ of +Strings+.
    #
    # *Example:*
    #
    #   service = Splunk::connect(:username => 'admin', 
    #                             :password => 'changeme')
    #   puts service.capabilities
    #   # Prints: ["admin_all_objects", "change_authentication",
    #   #          "change_own_password", "delete_by_keyword", ...]
    def capabilities
      response = request(:resource => PATH_CAPABILITIES)
      feed = AtomFeed.new(response.body)
      feed.entries[0]["content"]["capabilities"]
    end

    ##
    # Returns a +Collection+ of all the configuration files visible on Splunk.
    #
    # The configurations you see are dependent on the namespace your +Service+
    # is connected with. So if you are connected in the system namespace, you
    # may see different values than if you're connected in the app namespace
    # associated with a particular app, since the app may override some values
    # within its scope.
    #
    # The configuration files which are the contents of this +Collection+ are
    # not +Entity+ objects, but +Collection+ objects in their own right. They
    # contain +Entity+ objects representing the stanzas in that configuration
    # file.
    #
    # Returns: +Configurations+ (a subclass of +Collection+ containing
    # +ConfigurationFile+ objects).
    #
    def confs
      Configurations.new(self)
    end

    ##
    # Creates a blocking search.
    #
    # The +create_oneshot+ method starts a search _query_, and any optional 
    # arguments specified in a hash (which are identical to those taken by 
    # +create+). It then blocks until the job finished, and returns the 
    # results, as transformed by any transforming search commands in _query_ 
    # (equivalent to calling the +results+ method on a +Job+).
    #
    # Returns: a stream readable by +ResultsReader+.
    #
    def create_oneshot(query, args={})
      jobs.create_oneshot(query, args)
    end

    ##
    # Creates an asynchronous search job.
    #
    # The search job requires a _query_, and takes a hash of other, optional
    # arguments, which are documented in the {Splunk REST documentation}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs].
    #
    def create_search(query, args={})
      jobs.create(query, args)
    end

    ##
    # Creates a blocking search without transforming search commands.
    #
    # The +create_export+ method starts a search _query_, and any optional 
    # arguments specified in a hash (which are identical to those taken by 
    # the +create+ methods). It then blocks until the job is finished, and 
    # returns the events found by the job before any transforming search 
    # commands (equivalent to calling +events+ on a +Job+).
    #
    # Returns: a stream readable by +MultiResultsReader+.
    #
    def create_export(query, args={}) # :nodoc:
      jobs.create_export(query, args)
    end

    # DEPRECATED. Use create_export instead.
    def create_stream(query, args={})
      warn "[DEPRECATION] Service#create_stream is deprecated. Use Service#create_export instead."
      jobs.create_export(query, args)
    end

    ##
    # Returns a +Collection+ of all +Index+ objects.
    #
    # +Index+ is a subclass of +Entity+, with additional methods for
    # manipulating indexes in particular.
    #
    def indexes
      Collection.new(self, PATH_INDEXES, entity_class=Index)
    end

    ##
    # Returns a +Hash+ containing Splunk's runtime information.
    #
    # The +Hash+ has keys such as "+build+" (the number of the build of this
    # Splunk instance) and "+cpu_arch+" (what CPU Splunk is running on), and
    # "+os_name+" (the name of the operating system Splunk is running on).
    #
    # Returns: A +Hash+ that has +Strings+ as both keys and values.
    #
    def info
      response = request(:namespace => Splunk::namespace(:sharing => "default"),
                         :resource => PATH_INFO)
      feed = AtomFeed.new(response.body)
      feed.entries[0]["content"]
    end

    ##
    # Return a collection of the input kinds.
    #
    def inputs
      InputKinds.new(self, PATH_INPUTS)
    end

    ##
    # Returns a collection of all the search jobs running on Splunk.
    #
    # The +Jobs+ object returned is a subclass of +Collection+, but also has
    # convenience methods for starting oneshot and streaming jobs as well as
    # creating normal, asynchronous jobs.
    #
    # Returns: A +Jobs+ object.
    def jobs
      Jobs.new(self)
    end

    ##
    # Returns a collection of the loggers in Splunk.
    #
    # Each logger logs errors, warnings, debug info, or informational
    # information about a specific part of the Splunk system (e.g.,
    # +WARN+ on +DeploymentClient+).
    #
    # Returns: a +Collection+ of +Entity+ objects representing loggers.
    #
    # *Example*:
    #     service = Splunk::connect(:username => 'admin', :password => 'foo')
    #     service.loggers.each do |logger|
    #       puts logger.name + ":" + logger['level']
    #     end
    #     # Prints:
    #     #   ...
    #     #   DedupProcessor:WARN
    #     #   DeployedApplication:INFO
    #     #   DeployedServerClass:WARN
    #     #   DeploymentClient:WARN
    #     #   DeploymentClientAdminHandler:WARN
    #     #   DeploymentMetrics:INFO
    #     #   ...
    #
    def loggers
      Collection.new(self, PATH_LOGGER)
    end

    ##
    # Returns a collection of the global messages on Splunk.
    #
    # Messages include such things as warnings and notices that Splunk needs to
    # restart.
    #
    # Returns: A +Collection+ of +Message+ objects (which are subclasses 
    # of +Entity+).
    #
    def messages
      Messages.new(self, PATH_MESSAGES, entity_class=Message)
    end

    ##
    # Returns a read only collection of modular input kinds.
    #
    # The modular input kinds are custom input kinds on this Splunk instance.
    # To access the actual inputs of these kinds, use the +Service+#+inputs+
    # method. This method gives access to the metadata describing the input
    # kinds.
    #
    # Returns: A +ReadOnlyCollection+ of +ModularInputKind+ objects representing
    # all the custom input types added to this Splunk instance.
    #
    def modular_input_kinds
      if self.splunk_version[0] < 5
        raise IllegalOperation.new("Modular input kinds are " +
                                       "not supported before Splunk 5.0")
      else
        ReadOnlyCollection.new(self, PATH_MODULAR_INPUT_KINDS,
                               entity_class=ModularInputKind)
      end
    end

    ##
    # Returns a collection of the roles on the system.
    #
    # Returns: A +Collection+ of +Entity+ objects representing the roles on
    # this Splunk instance.
    #
    def roles
      CaseInsensitiveCollection.new(self, PATH_ROLES)
    end

    ##
    #
    #
    #
    def saved_searches
      Collection.new(self, PATH_SAVED_SEARCHES, entity_class=SavedSearch)
    end

    ##
    # Returns an +Entity+ of Splunk's mutable runtime information.
    #
    # The +settings+ method includes values such as "+SPLUNK_DB+" 
    # and "+SPLUNK_HOME+". Unlike the values returned by the +info+ method, 
    # these settings can be updated.
    #
    # Returns: an +Entity+ with all server settings.
    #
    # *Example*:
    #     service = Splunk::connect(:username => 'admin', :password => 'foo')
    #     puts svc.settings.read
    #     # Prints:
    #     #    {"SPLUNK_DB" => "/path/to/splunk_home/var/lib/splunk",
    #     #     "SPLUNK_HOME" => "/path/to/splunk_home",
    #     #     ...}
    #
    def settings
      # Though settings looks like a collection on the server, it always has
      # a single entity, of the same name, giving the actual settings. We access
      # that entity directly rather than putting a collection inbetween.
      Entity.new(self, Splunk::namespace(:sharing => "default"),
                 PATH_SETTINGS, "settings").refresh()
    end

    ##
    # Returns the version of Splunk this +Service+ is connected to.
    #
    # The version is represented as an +Array+ of length 3, with each
    # of its components an integer. For example, on Splunk 4.3.5,
    # +splunk_version+ would return [+4, 3, 5+], while on Splunk 5.0.2,
    # +splunk_version+ would return [+5, 0, 2+].
    #
    # Returns: An +Array+ of +Integers+ of length 3.
    #
    def splunk_version
      info["version"].split(".").map() {|v| Integer(v)}
    end

    ##
    # Return a +Collection+ of the users defined on Splunk.
    #
    def users
      CaseInsensitiveCollection.new(self, PATH_USERS)
    end
  end
end
