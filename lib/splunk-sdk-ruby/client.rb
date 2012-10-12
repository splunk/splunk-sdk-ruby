#require 'bundler/setup'
require 'cgi'
#TODO: Please get me working with json/ext - it SO much faster
require 'json/pure'
require 'json/stream'
require 'libxml'
require 'rubygems'

require_relative 'client/collection'
require_relative 'client/collection/conf_collection'
require_relative 'client/collection/jobs'
require_relative 'client/entity'
require_relative 'client/entity/conf'
require_relative 'client/entity/index'
require_relative 'client/entity/message'
require_relative 'client/job'
require_relative 'client/results_reader'
require_relative 'client/search_results'
require_relative 'client/service'

# FIXME(rdas) I'm an idiot because I couldn't find any way to pass local
# context variables to a block in the parser.  Thus the hideous monkey-patch
# and the 'obj' param.

class JSON::Stream::Parser
  def initialize(obj, &block)
    @state = :start_document
    @utf8 = JSON::Stream::Buffer.new
    @listeners = Hash.new{ |h, k| h[k] = [] }
    @stack, @unicode, @buf, @pos = [], '', '', -1
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
  key_list.each{ |key| result[key] = content[key] }

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
  PATH_CONFS = 'properties'
  PATH_CONF = 'configs/conf-%s'
  PATH_STANZA = 'configs/conf-%s/%s'
  PATH_JOBS = 'search/jobs'
  PATH_EXPORT = 'search/jobs/export'
  PATH_RESTART = 'server/control/restart'
  PATH_PARSE = 'search/parser'

  NAMESPACES = [
    'ns0:http://www.w3.org/2005/Atom', 'ns1:http://dev.splunk.com/ns/rest']
  MATCH_ENTRY_CONTENT = '/ns0:feed/ns0:entry/ns0:content'

end
