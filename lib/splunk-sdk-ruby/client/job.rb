module Splunk
  class Job
    def initialize(svc, sid)
      @service = svc
      @sid = sid
      @path = PATH_JOBS + '/' + sid
      @control_path = @path + '/control'
    end
    # Access an individual attribute named <b>+key+</b> about this job.
    # Note that this results in an HTTP round trip, fetching all values for the Job even though a single
    # attribute is returned.
    #
    # ==== Returns
    # A String representing the attribute fetched
    #
    # ==== Example - Display the disk usage of each job
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.jobs.list.each {|job| puts job['diskUsage'] }
    def [](key)
      obj = read([key])
      return obj[key]
    end

    # Return all or a specified subset of attribute/value pairs for this Job
    #
    # ==== Returns
    # A Hash of all attributes and values for this Job.  If Array <b>+field_list+</b> is specified,
    # only those fields are returned.  If a field does not exist, nil is returned for it's value.
    #
    # ==== Example - Return a Hash of all attribute/values for a list of Job
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.jobs.list.each do |job|
    #     dataHash = job.read
    #   end
    def read(field_list=nil)
      response = @service.context.get(@path)
      data = AtomResponseLoader::load_text(response)
      _filter_content(data['entry']['content'], field_list)
    end

    # Cancel this search job.  Stops the search and deletes the results cache.
    def cancel
      @service.context.post(@control_path, :action => 'cancel')
      self
    end

    # Disable preview generation for this job
    def disable_preview
      @service.context.post(@control_path, :action => 'disablepreview')
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
      @service.context.get(@path + '/events', args)
    end

    # Enable preview generation for this job.  This may slow the search down considerably.
    def enable_preview
      @service.context.post(@control_path, :action => 'enablepreview')
      self
    end

    # Finalize this search job. Stops the search and provides intermediate results
    # (retrievable via Job::results)
    def finalize
      @service.context.post(@control_path, :action => 'finalize')
      self
    end

    # Suspend this search job.
    def pause
      @service.context.post(@control_path, :action => 'pause')
      self
    end

    # Generate a preview for this search Job.  Results are always in JSON.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fresults_preview]
    # for more info on valid parameters and results.
    def preview(args={})
      @service.context.get(@path + '/results_preview', args)
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
      args[:output_mode] = 'json'
      @service.context.get(@path + '/results', args)
    end

    # Returns the search.log for this search Job.  Only a few lines of the search log are returned.
    # See {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fsearch.log]
    # for more info on valid parameters and results.
    def searchlog(args={})
      @service.context.get(@path + 'search.log', args)
    end

    # Sets the priority of this search Job.  <b>+value+</b> can be 0-10.
    def setpriority(value)
      @service.context.post(
        @control_path, :action => 'setpriority', :priority => value)
      self
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
      @service.context.get(@path + 'timeline', args)
    end

    # Extends the expiration time of the search for this Job to now + ttl (see Job::setttl for setting the ttl)
    def touch
      @service.context.post(@control_path, :action => 'touch')
      self
    end

    # Set the time-to-live (ttl) of the search for this Job. <b>+value+</b> is a number
    def setttl(value)
      @service.context.post(@control_path, :action => 'setttl', :ttl => value)
    end

    # Resumes execution of the search for this Job.
    def unpause
      @service.context.post(@control_path, :action => 'unpause')
      self
    end
  end
end
