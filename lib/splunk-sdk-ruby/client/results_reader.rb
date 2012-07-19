module Splunk
  # This class allows clients to enumerate events that are the results of a streaming search via the
  # Splunk::Jobs::create_stream call.  This enumeration is done in a 'chunked' way - that is the results
  # are not all streamed into a large in-memory JSON data structure, but pulled as ResultsReader::each is called.
  class ResultsReader
    include Enumerable

    def initialize(socket)
      @socket = socket
      @events = []

      callbacks = proc do
        start_document { @array_depth = 0 }

        end_document {}

        start_object { @event = {} }

        end_object { @obj.event_found(@event) }

        start_array {
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
        }

        key { |k| @k = k }

        value { |v|
          if @isarray
            @array << v
          else
            @event[@k] = v
          end
        }
      end

      @parser = JSON::Stream::Parser.new(self, &callbacks)
    end

    def close # :nodoc:
      @socket.close()
    end

    def event_found(event) # :nodoc:
      @events << event
    end

    def read # :nodoc:
      data = @socket.read(4096)
      return nil if data.nil?
      #TODO: Put me in to show [] at end of events bug
      #puts String(data.size) + ':' + data
      @parser << data
      data.size
    end

    # Calls block once for each returned event
    #
    # ==== Example 1 - Simple streamed search
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   reader = svc.jobs.create_stream('search host="45.2.94.5" | timechart count')
    #   reader.each {|event| puts event}
    def each(&block)  # :yields: event
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
end
