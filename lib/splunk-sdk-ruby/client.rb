require_relative 'collection'
require_relative 'collection/configurations'
require_relative 'collection/configuration_file'
require_relative 'collection/jobs'
require_relative 'collection/messages'
require_relative 'entity'
require_relative 'entity/stanza'
require_relative 'entity/index'
require_relative 'entity/message'
require_relative 'entity/job'
require_relative 'service'

# :stopdoc:
def _filter_content(content, key_list=nil, add_attrs=true)
  if key_list.nil?
    return content.add_attrs if add_attrs
    return content
  end
  result = {}
  key_list.each{ |key| result[key] = content[key] }

  return result.add_attrs if add_attrs
  result
end


def _path_stanza(conf, stanza)
  Splunk::PATH_STANZA % [conf, CGI::escape(stanza)]
end
# :startdoc:


module Splunk
  PATH_APPS_LOCAL = ["apps", "local"]
  PATH_CAPABILITIES = ["authorization", "capabilities"]
  PATH_LOGGER = ["server","logger"]
  PATH_ROLES = ["authentication", "roles"]
  PATH_USERS = ['authentication','users']
  PATH_MESSAGES = ['messages']
  PATH_INFO = ["server", "info"]
  PATH_SETTINGS = ["server", "settings"]
  PATH_INDEXES = ["data","indexes"]
  PATH_CONFS = ["properties"]
  PATH_CONF = ["configs"]
  PATH_STANZA = ["configs","conf-%s","%s"]
  PATH_JOBS = ["search", "jobs"]
  PATH_EXPORT = ["search", "jobs", "export"]
  PATH_RESTART = ["server", "control", "restart"]
  PATH_PARSE = ["search", "parser"]

  NAMESPACES = { 'ns0' => 'http://www.w3.org/2005/Atom',
                 'ns1' => 'http://dev.splunk.com/ns/rest' }
  MATCH_ENTRY_CONTENT = '/ns0:feed/ns0:entry/ns0:content'

end
