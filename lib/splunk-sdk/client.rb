require_relative 'aloader'
require_relative 'context'
require 'libxml'
require 'cgi'
require 'json/pure' #TODO: Please get me working with json/ext - it SO much faster

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

NAMESPACES = ['ns0:http://www.w3.org/2005/Atom', 'ns1:http://dev.splunk.com/ns/rest']
NAMESPACES_SEARCH = ['ns0:http://www.w3.org/2005/Atom', 's:http://dev.splunk.com/ns/rest']

MATCH_ENTRY_CONTENT = '/ns0:feed/ns0:entry/ns0:content'
MATCH_ENTRY_CONTENT_SEARCH = 's:entry/s:content'

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

class Service
  attr_reader :context

  def initialize(args)
    @context = Context.new(args)
    @context.login
  end

  def apps
    create_collection(PATH_APPS_LOCAL)
  end

  def capabilities
    response = @context.get(PATH_CAPABILITIES)
    record = AtomResponseLoader::load_text_as_record(response, MATCH_ENTRY_CONTENT, NAMESPACES)
    record.content.capabilities
  end

  def info
    response = @context.get(PATH_INFO)
    record = AtomResponseLoader::load_text_as_record(response, MATCH_ENTRY_CONTENT, NAMESPACES)
    record.content
  end

  def loggers
    item = Proc.new {|service, name| Entity.new(service, PATH_LOGGER + '/' + name, name)}
    Collection.new(self, PATH_LOGGER, "loggers", :item => item)
  end

  def settings
    Entity.new(self, PATH_SETTINGS, "settings")
  end

  def indexes
    item = Proc.new {|service, name| Index.new(service, name)}
    ctor = Proc.new { |service, name, args|
      new_args = args
      new_args[:name] = name
      service.context.post(PATH_INDEXES, new_args)
    }
    Collection.new(self, PATH_INDEXES, "loggers", :item => item, :ctor => ctor)
  end

  def roles
    create_collection(PATH_ROLES, "roles")
  end

  def users
    create_collection(PATH_USERS, "users")
  end

  def jobs
    Jobs.new(self)
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

def connect(args)
  Service.new args
end



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
      record.feed.entry.each do |entry|              ``
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

    #TODO: DO NOT RETURN SID HERE
    sid = AtomResponseLoader::load_text(response, MATCH_ENTRY_CONTENT, NAMESPACES)
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

=begin

s = connect(:username => 'admin', :password => 'sk8free')

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
s = connect(:username => 'admin', :password => 'sk8free')
jobs = s.jobs
p jobs.list
jobs.list.each do |sid|
  job = Job.new(s, sid)
  puts job['diskUsage']
end

#result = jobs.create("search *", :exec_mode => 'oneshot', :output_mode => 'json')
#puts '********************************'
#puts result

result = jobs.create_oneshot("search *", :max_count => 1000, :max_results => 1000)
result.each {|row| puts row['_raw']}
puts result.count

