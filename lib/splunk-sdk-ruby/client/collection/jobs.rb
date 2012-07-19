module Splunk
# Jobs objects are used for executing searches and retrieving a list of all jobs
  class Jobs < Collection
    def initialize(svc)
      @service = svc
      item = Proc.new {|service, sid| Job.new(service, sid)}
      super(svc, PATH_JOBS, 'jobs', :item => item)
    end

    # Run a search.  This search can be either synchronous (oneshot) or asynchronous.  A synchronous search
    # will execute the search and the caller will block until the results have been returned.  An asynchronous search
    # will return immediately, returning a Job object that can be queried for completion, paused, etc.
    # There are many possible arguments - all are documented in the Splunk REST documentation at
    # http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs - POST.  The one that controls
    # either synchronous or asynchronous is called <b>+:exec_mode+</b>.
    #
    # ==== Example 1 - Execute a synchronous search returning XML (XML is the default output mode )
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.jobs.create("search error", :max_count => 10, :max_results => 10, :exec_mode => 'oneshot')
    #
    # ==== Example 2 - Execute a synchronous search returning results in JSON
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   puts svc.jobs.create("search error", :max_count => 10, :max_results => 10, :exec_mode => 'oneshot', :output_mode => 'json')
    #
    # ==== Example 3 - Execute a synchronous search returning a Job object with the results as a JSON String
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   job = svc.jobs.create("search error", :max_count => 10, :max_results => 10, :exec_mode => 'blocking')
    #   puts job.results(:output_mode => 'json')
    #
    # ==== Example 4 - Execute an asynchronous search and wait for all the results (returned in JSON)
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   job = svc.jobs.create("search error", :max_count => 10, :max_results => 10)
    #   while true
    #     stats = job.read(['isDone'])
    #     break if stats['isDone'] == '1'
    #     sleep(1)
    #   end
    #   puts job.results(:output_mode => 'json')
    def create(query, args={})
      args['search'] = query
      response = @service.context.post(PATH_JOBS, args)

      return response if args[:exec_mode] == 'oneshot'

      response = AtomResponseLoader::load_text(response)
      sid = response['response']['sid']
      Job.new(@service, sid)
    end

    #Convenience method that runs a synchronous search returning an enumerable SearchResults object. This
    #object allows you to iterate through each individual event.
    #You can use any arguments from the REST call (specfied in Jobs.create) you wish,
    #but ':exec_mode' and ':output_mode' will always be set to 'oneshot' and 'json' respectively.
    #
    #==== Example - Execute a search and show just the raw events followed by the event count
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   results = svc.jobs.create_oneshot("search error", :max_count => 10, :max_results => 10)
    #   results.each {|event| puts event['_raw']}
    #   puts results.count
    def create_oneshot(query, args={})
      args[:search] = query
      args[:exec_mode] = 'oneshot'
      args[:output_mode] = 'json'
      response = @service.context.post(PATH_JOBS, args)

      begin
        json = JSON.parse(response)
        SearchResults.new(json)
      rescue JSON::ParserError
        SearchResults.new(Array.new)
      end

    end

    # Run a <b>streamed search</b> .  Rather than returning an object that can take up a huge amount of memory by including
    # large numbers of search results, a streamed search buffers only a chunk at a time and provides an interface
    # that the client can use to retrieve results without taking up any more memory than just for the buffer itself.
    # The arguments are exactly the same as for the other search methods in this class except that <b>+:output_mode+</b>
    # will always be 'json' because results are always in JSON.
    #
    # Returns a Splunk::ResultsReader object
    #
    # ==== Example 1 - Simple streamed search
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   reader = svc.jobs.create_stream('search host="45.2.94.5" | timechart count')
    #   reader.each {|event| puts event}
    #
    # ==== Example 2 - Real time streamed search
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   reader = svc.jobs.create_stream('search index=_internal',\
    #   :search_mode => 'realtime', :earliest_time => 'rt-1m', :latest_time => 'rt')
    #   reader.each {|event| puts event} #will block until events show up in real-time
    def create_stream(query, args={})
      args[:search] = query
      args[:output_mode] = 'json'

      path = PATH_EXPORT + "?#{args.urlencode}"

      cn = @service.context.connect
      cn.write("GET #{@service.context.fullpath(path)} HTTP/1.1\r\n")
      cn.write("Host: #{@service.context.host}:#{@service.context.port}\r\n")
      cn.write("User-Agent: splunk-sdk-ruby/0.1\r\n")
      cn.write("Authorization: Splunk #{@service.context.token}\r\n")
      cn.write('Accept: */*\r\n')
      cn.write('\r\n')

      cn.readline  # return code TODO: Parse me and return error if problem
      cn.readline  # accepts
      cn.readline  # blank

      ResultsReader.new(cn)
    end

    # Return an Array of Jobs
    #
    # ==== Example - Display the disk usage of each job
    #   svc = Splunk::Service.connect(:username => 'admin', :password => 'foo')
    #   svc.jobs.list.each {|job| puts job['diskUsage'] }
    def list
      response = @service.context.get(PATH_JOBS)
      entry = AtomResponseLoader::load_text_as_record(
        response, MATCH_ENTRY_CONTENT, NAMESPACES)
      return [] if entry.nil?
      entry = [entry] if !entry.is_a? Array
      retarr = []
      entry.each{ |item| retarr << Job.new(@service, item.content.sid) }
      retarr
    end
  end
end
