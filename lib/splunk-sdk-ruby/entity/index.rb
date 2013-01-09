#--
# Copyright 2011-2012 Splunk, Inc.
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

##
# Provides a class +Index+ to represent indexes on the Splunk server.
#

require_relative '../entity'

module Splunk
  ##
  # Class representing an index on the Splunk server.
  #
  # Beyond what its superclass +Entity+ provides, +Index+ also exposes methods
  # to write data to an index and delete all data from an index.
  #
  class Index < Entity
    # Open a socket to write events to this index.
    #
    # Write events to the returned stream Socket, and Splunk will index the
    # data. You can optionally pass a hash of _host_, _source_, and
    # _sourcetype_ arguments to be sent with every event.
    #
    # Splunk may not index submitted events until the socket is closed or
    # at least 1MB of data has been submitted.
    #
    # You are responsible for closing the socket.
    #
    # Note that +SSLSocket+ and +TCPSocket+ have incompatible APIs.
    #
    # Returns: an +SSLSocket+ or +TCPSocket+.
    #
    # *Example*:
    #
    #     service = Splunk::connect(:username => 'admin', :password => 'foo')
    #     stream = service.indexes['main'].attach(:sourcetype => 'mysourcetype')
    #     (1..5).each { stream.write("This is a cheezy event\r\n") }
    #     stream.close()
    #
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

    ##
    # Delete all events in this index.
    #
    # +clean+ will wait until the operation completes, or _timeout_
    # seconds have passed. By default, _timeout_ is 100 seconds.
    #
    # Cleaning an index is done by setting +maxTotalDataSizeMG+ and
    # +frozenTimePeriodInSecs+ to +"1"+.
    #
    # Returns: the +Index+.
    #
    def clean(timeout=100)
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

    ##
    # Tell Splunk to roll the hot buckets in this index now.
    #
    # A Splunk index is a collection of buckets containing events. A bucket
    # begins life "hot", where events may be written into it. At some point,
    # when it grows to a certain size, or when +roll_hot_buckets+ is called,
    # it is rolled to "warm" and a new hot bucket created. Warm buckets are
    # fully accessible, but not longer receiving new events. Eventually warm
    # buckets are archived to become cold buckets.
    #
    # Returns: the +Index+.
    #
    def roll_hot_buckets()
      @service.request(:method => :POST,
                       :resource => @resource + [@name, "roll-hot-buckets"])
      return self
    end

    ##
    # Write a single event to this index.
    #
    # _event_ is the text of the event. You can optionally pass a hash
    # with the optional keys +:host+, +:source+, and +:sourcetype+.
    #
    # Returns: the +Index+.
    #
    # *Example:*
    #   service = Splunk::connect(:username => 'admin', :password => 'foo')
    #   service.indexes['main'].submit("this is an event",
    #                                  :host => "baz",
    #                                  :sourcetype => "foo")
    #
    def submit(event, args={})
      args[:index] = @name
      @service.request(:method => :POST,
                       :resource => ["receivers", "simple"],
                       :query => args,
                       :body => event)
      return self
    end

    ##
    # Upload a file accessible by the Splunk server.
    #
    # _filename_ should be the full path to the file on the server where
    # Splunk is running. Besides _filename_, +upload+ also takes a hash of
    # optional arguments, all of which take +String+s:
    #
    # * +:host+ - The host for the events
    # * +:host_regex+ - A regex to be used to extract a 'host' field from
    #   the path. If the path matches this regular expression, the captured
    #   value is used to populate the 'host' field or events from this data
    #   input.  The regular expression must have one capture group.
    # * +:host_segment+ - Use the specified slash-seperated segment of the
    #   path as the host field value.
    # * +:rename-source+ - The value of the 'source' field to be applied to the
    #   data from this file
    # * +:sourcetype+ - The value of the 'sourcetype' field to be applied to
    #   data from this file
    #
    def upload(filename, args={})
      args['index'] = @name
      args['name'] = filename
      @service.request(:method => :POST,
                       :resource => ["data", "inputs", "oneshot"],
                       :body => args)
    end
  end
end
