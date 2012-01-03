require_relative 'aloader'
require_relative 'context'
require 'libxml'
require 'cgi'
require 'json/pure' #TODO: Please get me working with json/ext - it SO much faster
require 'json/stream'

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
  PATH_STANZA % [conf, CGI::escape(stanza)]
end

##
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
  #   svc = Service.new(:username => 'admin', :password => 'foo')
  #   svc = Service.new(:username => 'admin', :password => 'foo', :host => '10.1.1.1', :port = '9999')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
  #   svc.apps #get a list of apps (we can do this because we are logged in)
  def self.connect(args)
    svc = Service.new args
    svc.login
    svc
  end

  # Log into Splunk
  #
  # ==== Examples
  #   svc = Service.new(:username => 'admin', :password => 'foo')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
  #   svc.apps.delete('sample_app')
  #
  # ==== Example 3 - display permissions for the sample app
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
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
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
  #   svc.users.create('jack', :password => 'mypassword', :realname => 'Jack_be_nimble', :roles => ['user'])
  #   svc.users.each {|i| puts i.name + ':' + String(i.read) }
  #     admin:{"defaultApp"=>"launcher", "defaultAppIsUserOverride"=>"1", "defaultAppSourceRole"=>"system",
  #     jack:{"defaultApp"=>"launcher", "defaultAppIsUserOverride"=>"0", "defaultAppSourceRole"=>"system",
  def users
    create_collection(PATH_USERS, "users")
  end

  # Returns a new Jobs Object
  #
  # ==== Returns
  #   A new Jobs Object
  #
  # ==== Example - Get a list of all current jobs
  #   svc = Service.connect(:username => 'admin', :password => 'foo')
  #   puts svc.jobs.list
  #     1325621349.33
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
  #   A JSON structure with information about the search
  #
  # ==== Example - Parse a simple search
  #   puts s.parse("search error")

  def parse(query, args={})
    args['q'] = query
    args['output_mode'] = 'json'
    @context.get(PATH_PARSE, args)
  end

  def confs
    item = Proc.new {|service, conf| ConfCollection.new(self, conf) }
    Collection.new(self, PATH_CONFS, "confs", :item => item)
  end

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

  def create_collection(path, collection_name=nil)
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

  def init_default(key, deflt)
    if @procs.has_key?(key)
      return @procs[key]
    end
    deflt
  end

  def each(&block)
    self.list().each do |name|
      yield @item.call(@service, name)
    end
  end

  def delete(name)
    raise NotImplmentedError if @dtor.nil?
    @dtor.call(@service, name)
    return self
  end

  def create(name, args={})
    raise NotImplementedError if @ctor.nil?
    @ctor.call(@service, name, args)
    return self[name]
  end

  def [](key)
    raise NotImplmentedError if @item.nil?
    raise KeyError if !contains?(key)
    @item.call(@service, key)
  end

  def contains?(name)
    list().include?(name)
  end

  #TODO: Need method 'itemmeta'

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

class Entity
  attr_reader :name

  def initialize(service, path, name=nil)
    @service = service
    @path = path
    @name = name
  end

  def [](key)
    obj = read([key])
    #obj.send(key)
    return obj[key]
  end

  def []=(key, value)
    update(key => value)
  end

  def read(field_list=nil)
    response = @service.context.get(@path)
    data = AtomResponseLoader::load_text(response, MATCH_ENTRY_CONTENT, NAMESPACES)
    _filter_content(data["content"], field_list)
  end

  def readmeta()
    read(['eai:acl', 'eai:attributes'])
  end

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

class Message < Entity
  def initialize(service, name)
    super(service, PATH_MESSAGES + '/' + name, name)
  end

  def value
    self[@name]
  end
end

class Index < Entity
  def initialize(service, name)
    super(service, PATH_INDEXES + '/' + name, name)
  end

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

  def submit(event, host=nil, source=nil, sourcetype=nil)
    args = {:index => @name}
    args['host'] = host if host
    args['source'] = source if source
    args['sourcetype'] = sourcetype if sourcetype

    path = "receivers/simple?#{args.urlencode}"
    @service.context.post(path, event, {})
  end

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

  def read(field_list=nil)
    response = @service.context.get(@path)
    data = AtomResponseLoader::load_text(response, MATCH_ENTRY_CONTENT, NAMESPACES)
    _filter_content(data["content"], field_list, false)
  end

  def submit(stanza)
    @service.context.post(@path, stanza, {})
  end
end

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

class Jobs < Collection
  def initialize(svc)
    @service = svc
    item = Proc.new {|service, sid| Job.new(service, sid)}
    super(svc, PATH_JOBS, "jobs", :item => item)
  end

  def create(query, args={})
    args["search"] = query
    response = @service.context.post(PATH_JOBS, args)

    return response if args[:exec_mode] == 'oneshot'

    response = AtomResponseLoader::load_text(response)
    sid = response['response']['sid']
    Job.new(@service, sid)
  end

  def create_oneshot(query, args={})
    args[:search] = query
    args[:exec_mode] = "oneshot"
    args[:output_mode] = "json"
    response = @service.context.post(PATH_JOBS, args)

    json = JSON.parse(response)
    SearchResults.new(json)
  end

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

  def list
    response = @service.context.get(PATH_JOBS)
    entry = AtomResponseLoader::load_text_as_record(response, MATCH_ENTRY_CONTENT, NAMESPACES)
    return [] if entry.nil?
    entry = [entry] if !entry.is_a? Array
    retarr = []
    entry.each {|item| retarr << item.content.sid}
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

  def [](key)
    obj = read([key])
    return obj[key]
  end

  def read(field_list=nil)
    response = @service.context.get(@path)
    data = AtomResponseLoader::load_text(response)
    _filter_content(data["entry"]["content"], field_list)
  end

  def cancel
    @service.context.post(@control_path, :action => 'cancel')
    self
  end

  def disable_preview
    @service.context.post(@control_path, :action => 'disablepreview')
    self
  end

  def events(args={})
    args[:output_mode] = 'json'
    @service.context.get(@path + '/events', args)
  end

  def enable_preview
    @service.context.post(@control_path, :action => 'enablepreview')
    self
  end

  def finalize
    @service.context.post(@control_path, :action => 'finalize')
    self
  end

  def pause
    @service.context.post(@control_path, :action => 'pause')
    self
  end

  def preview(args={})
    @service.context.get(@path + '/results_preview', args)
  end

  def results(args={})
    args[:output_mode] = 'json'
    @service.context.get(@path + '/results', args)
  end

  def searchlog(args={})
    @service.context.get(@path + 'search.log', args)
  end

  def setpriority(value)
    @service.context.post(@control_path, :action => 'setpriority', :priority => value)
    self
  end

  def summary(args={})
    @service.context.get(@path + '/summary', args)
  end

  def timeline(args={})
    @service.context.get(@path + 'timeline', args)
  end

  def touch
    @service.context.post(@control_path, :action => 'touch')
    self
  end

  def setttl(value)
    @service.context.post(@control_path, :action => 'setttl', :ttl => value)
  end

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

  def close
    @socket.close()
  end

  def event_found(event)
    @events << event
  end

  def read
    data = @socket.read(4096)
    return nil if data.nil?
    #TODO: Put me in to show [] at end of events bug
    #puts String(data.size) + ':' + data
    @parser << data
    data.size
  end

  def each(&block)
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

=begin

s = Service::connect(:username => 'admin', :password => 'sk8free')

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
s = Service::connect(:username => 'admin', :password => 'sk8free')

reader = s.jobs.create_stream('search host="45.2.94.5" | timechart count')
reader.each {|event| puts event}

puts s.parse("search error")
#job = s.jobs.create("search * | stats count", :max_count => 1000, :max_results => 1000)

#p s.settings.read
#s.loggers.each {|logger| puts logger.name + ":" + logger['level']}

#reader.close

#job = s.jobs.create("search * | stats count", :max_count => 1000, :max_results => 1000)

#while true
#  stats = job.read(['isDone'])
#  break if stats['isDone'] == '1'
#  sleep(1)
#end

#puts job.results(:output_mode => 'json')

#result = jobs.create("search *", :exec_mode => 'oneshot', :output_mode => 'json')
#puts '********************************'
#puts result

#result = jobs.create_oneshot("search *", :max_count => 1000, :max_results => 1000)
#result.each {|row| puts row['_raw']}
#puts result.count

#jobs = s.jobs
#p jobs.list
#jobs.list.each do |sid|
#  job = Job.new(s, sid)
#  puts job['diskUsage']
#end