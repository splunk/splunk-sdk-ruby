module Splunk
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
      cn.write('X-Splunk-Input-Mode: Streaming\r\n')
      cn.write('\r\n')
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
      path = 'data/inputs/oneshot'
      @service.context.post(path, args)
    end
  end
end
