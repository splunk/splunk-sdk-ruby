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

module Splunk
  class Job < Entity
    def initialize(service, sid)
      super(service, Splunk::namespace("global"), PATH_JOBS, sid)
      refresh() # Jobs don't return their state on creation
    end

    # Cancel this search job.  Stops the search and deletes the results cache.
    def cancel
      begin
        control(:action => "cancel")
      rescue SplunkHTTPError => err
        if err.code == 404
          return self # Job already cancelled; cancelling twice is a nop.
        else
          raise err
        end
      end
    end

    def control(args)
      @service.request(:method => :POST,
                       :namespace => @namespace,
                       :resource => @resource + [sid, "control"],
                       :body => args)
      self
    end

    # Returns the events of this search job.
    # These events are the data from the search pipeline before the first "transforming" search command.
    # This is the primary method for a client to fetch a set of UNTRANSFORMED events for this job.
    # This call is only valid if the search has no transforming commands. Set <b>+:output_mode+</b> to 'json' if you
    # want results in JSON.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fevents]
    # for more info on valid parameters and results.
    def events(args={})
      response = @service.request(
          :method => :GET,
          :resource => @resource + [sid, "events"],
          :body => args)
      return response.body
    end

    # Enable preview generation for this job.  This may slow the search down considerably.
    def enable_preview
      control(:action => "enablepreview")
    end

    # Finalize this search job. Stops the search and provides intermediate results
    # (retrievable via Job::results)
    def finalize
      control(:action => "finalize")
    end

    def is_done()
      refresh()
      return fetch("isDone") == "1"
    end

    # Suspend this search job.
    def pause
      control(:action => "pause")
    end

    # Generate a preview for this search Job.  Results are always in JSON.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fresults_preview]
    # for more info on valid parameters and results.
    def preview(args={})
      response = @service.request(:method => :GET,
                                  :resource => @resource +
                                      [sid, "results_preview"],
                                  :body => args)
      return response.body
    end

    # Returns the current results of the search for this job.  This is the table that exists after all processing
    # from the search pipeline has completed.  This is the primary method for a client to fetch a set of
    # TRANSFORMED events.  If the dispatched search doesn't include a transforming command, the effect is the same
    # as Job::events.   Set <b>+:output_mode+</b> to 'json' if you
    # want results in JSON.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fresults]
    # for more info on valid parameters and results.

    # ==== Example 1 - Execute a blocking (synchronous) search returning the results
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   job = svc.jobs.create("search error", :max_count => 10, :max_results => 10, :exec_mode => 'blocking')
    #   puts job.results(:output_mode => 'json')
    #
    # ==== Example 2 - Execute an asynchronous search and wait for all the results
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   job = svc.jobs.create("search error", :max_count => 10, :max_results => 10)
    #   while true
    #     stats = job.read(['isDone'])
    #     break if stats['isDone'] == '1'
    #     sleep(1)
    #   end
    #   puts job.results(:output_mode => 'json')
    def results(args={})
      response = @service.request(:resource => @resource + [sid, "results"],
                                  :body => args)
      return response.body
    end

    # Returns the search.log for this search Job.  Only a few lines of the search log are returned.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fsearch.log]
    # for more info on valid parameters and results.
    def searchlog(args={})

      @service.context.get(@path + 'search.log', args)
    end

    # Sets the priority of this search Job.  <b>+value+</b> can be 0-10.
    def set_priority(value)
      control(:action => "setpriority", :priority => value)
    end

    def sid
      fetch("sid")
    end

    # Returns field summary information that is usually used to populate the fields picker
    # in the default search view in the Splunk GUI. Note that results are ONLY available in XML.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fsummary]
    # for more info on valid parameters and results.
    def summary(args={})
      @service.context.get(@path + '/summary', args)
    end

    # Returns event distribution over time of the so-far-read untransformed events.  Results are ONLY
    # available in XML.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Ftimeline]
    # for more info on valid parameters and results.
    def timeline(args={})
      response = @service.request(:resource => @resource + [sid, "timeline"],
                                  :body => args)
      if $default_xml_library == :nokogiri
        doc = Nokogiri::XML(response.body)
        matches = doc.xpath("/timeline/bucket").map() do |bucket|
          {:a => Integer(bucket.attributes["a"].to_s),
           :c => Integer(bucket.attributes["c"].to_s),
           :t => Float(bucket.attributes["t"].to_s),
           :d => Integer(bucket.attributes["d"].to_s),
           :f => Integer(bucket.attributes["f"].to_s),
           :etz => Integer(bucket.attributes["etz"].to_s),
           :ltz => Integer(bucket.attributes["ltz"].to_s),
           :time => bucket.children.to_s}
        end
        return matches
      else
        doc = REXML::Document.new(response.body)
        matches = []
        matches = doc.elements.map("/timeline/bucket") do |bucket|
          {:a => Integer(bucket.attributes["a"]),
           :c => Integer(bucket.attributes["c"]),
           :t => Float(bucket.attributes["t"]),
           :d => Integer(bucket.attributes["d"]),
           :f => Integer(bucket.attributes["f"]),
           :etz => Integer(bucket.attributes["etz"]),
           :ltz => Integer(bucket.attributes["ltz"]),
           :time => bucket.children.join("")}
        end
        return matches
      end
    end

    # Extends the expiration time of the search for this Job to now + ttl (see Job::setttl for setting the ttl)
    def touch
      control(:action => "touch")
    end

    # Set the time-to-live (ttl) of the search for this Job. <b>+value+</b> is a number
    def set_ttl(value)
      control(:action => "setttl", :ttl => value)
    end

    # Resumes execution of the search for this Job.
    def unpause
      control(:action => "unpause")
    end
  end
end
