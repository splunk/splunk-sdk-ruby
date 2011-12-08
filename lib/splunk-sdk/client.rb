require_relative 'aloader'
require_relative 'context'
require 'libxml'

PATH_APPS_LOCAL = 'apps/local'
PATH_CAPABILITIES = 'authorization/capabilities'
PATH_LOGGER = 'server/logger'
PATH_ROLES = 'authentication/roles'
PATH_USERS = 'authentication/users'
PATH_MESSAGES = 'messages'
PATH_INFO = 'server/info'
PATH_SETTINGS = 'server/settings'


NAMESPACES = ['ns0:http://www.w3.org/2005/Atom', 'ns1:http://dev.splunk.com/ns/rest']
MATCH_ENTRY_CONTENT = '/ns0:feed/ns0:entry/ns0:content'

def _filter_content(content, key_list=nil)
  if key_list.nil?
    return content.to_obj
  end
  result = {}
  key_list.each {|key| result[key] = content[key]}
  result.to_obj
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
    return record.content
  end

  def loggers
    item = Proc.new {|service, name| Entity.new(service, PATH_LOGGER + '/' + name, name)}
    Collection.new(self, PATH_LOGGER, "loggers", :item => item)
  end

  def settings
    return Entity.new(self, PATH_SETTINGS, "settings")
  end

  def roles
    create_collection(PATH_ROLES, "roles")
  end

  def users
    create_collection(PATH_USERS, "users")
  end

  def messages
    item = Proc.new {|service, name| Message.new(service, name)}
    ctor = Proc.new { |service, name, args|
      new_args = args
      new_args[:name] = name
      service.context.post(path, new_args)
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
  end

  def create(name, args={})
    raise NotImplementedError if @ctor.nil?
    @ctor.call(@service, name, args)
  end

  def list
    retval = []
    response = @service.context.get(@path, :count => -1)
    record = AtomResponseLoader::load_text_as_record(response)
    return retval if !record.feed.instance_variable_defined?('@entry')
    record.feed.entry.each do |entry|
      retval << entry["title"] #because 'entry' is an array we don't allow dots
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
    obj.send(key)
  end

  def []=(key, value)
    update(key => value)
  end

  def read(field_list=nil)
    response = @service.context.get(@path)
    data = AtomResponseLoader::load_text(response, MATCH_ENTRY_CONTENT, NAMESPACES)
    return _filter_content(data["content"], field_list)
  end

  def readmeta()
    read(['eai:acl', 'eai:attributes'])
  end

  def update(args)
    response = @service.context.post(@path, args)
    self
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
