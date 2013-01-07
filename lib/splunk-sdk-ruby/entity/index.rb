module Splunk
# Splunk can have many indexes.  Each index is represented by an Index object.
  class Index < Entity
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
    def attach(args={})
      args[:index] = @name
      path = "receivers/stream?#{URI.encode_www_form(args)}"

      path = (@service.namespace.to_path_fragment() + ["receivers","stream"]).
          map {|fragment| URI::encode(fragment)}.
          join("/")
      query = URI.encode_www_form(args)

      cn = @service.connect
      headers = "POST /#{path}?#{query} HTTP/1.1\r\n" +
          "Host: #{@service.host}:#{@service.port}\r\n" +
          "Accept-Encoding: identity\r\n" +
          "Authorization: Splunk #{@service.token}\r\n" +
          "X-Splunk-Input-Mode: Streaming\r\n" +
          "\r\n"
      cn.write(headers)
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
    def clean(timeout=nil)
      refresh()
      original_state = read(['maxTotalDataSizeMB', 'frozenTimePeriodInSecs'])
      was_disabled_initially = fetch("disabled") == "1"
      if (!was_disabled_initially && @service.splunk_version[0] < 5)
        disable()
      end

      update(:maxTotalDataSizeMB => 1, :frozenTimePeriodInSecs => 1)
      roll_hot_buckets()

      Timeout::timeout(timeout) do
        while true
          refresh()
          if fetch("totalEventCount") == "0"
            break
          else
            sleep(1)
          end
        end
      end

      # Restore the original state
      if !was_disabled_initially
        enable()
      end
      update(original_state)
    end

    def roll_hot_buckets()
      @service.request(:method => :POST,
                       :resource => @resource + [@name, "roll-hot-buckets"])
      return self
    end

    # Batch HTTP(S) input for Splunk. Specify one or more events in a String along with optional
    # <b>+host+</b>, <b>+source+</b> or <b>+sourcetype+</b> fields which will apply to all events.
    #
    # Example - Index a single event into the 'main' index with source 'baz' and sourcetype 'foo'
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.indexes['main'].submit("this is an event", nil, "baz", "foo")
    #
    # Example 2 - Index multiple events into the 'main' index with default metadata
    def submit(events, args={})
      args[:index] = @name
      @service.request(:method => :POST,
                       :resource => ["receivers", "simple"],
                       :query => args,
                       :body => events)
      return self
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
      @service.request(:method => :POST,
                       :resource => ["data", "inputs", "oneshot"],
                       :body => args)
    end
  end
end
