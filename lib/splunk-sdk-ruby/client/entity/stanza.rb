module Splunk
  class Stanza < Entity
    # ==== Example 2 - Display a Hash of configuration lines on a particular stanza
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   confs = svc.confs             #Return a Collection of ConfCollection objects (config files)
    #   stanzas = confs['props']      #Return a ConfCollection (stanzas in a config file)
    #   stanza = stanzas['manpage']   #Return a Conf object (lines in a stanza)
    #   puts stanza.read
    #     {"ANNOTATE_PUNCT"=>"1", "BREAK_ONLY_BEFORE"=>"gooblygook", "BREAK_ONLY_BEFORE_DATE"=>"1",...}
    def read(field_list=nil)
      response = @service.context.get(@path)
      data = AtomResponseLoader::load_text(
        response, MATCH_ENTRY_CONTENT, NAMESPACES)
      _filter_content(data['content'], field_list, false)
    end

    #Populate a stanza in the .conf file
    def submit(stanza)
      @service.context.post(@path, stanza, {})
    end
  end
end
