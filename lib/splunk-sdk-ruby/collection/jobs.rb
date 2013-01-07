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
# Jobs objects are used for executing searches and retrieving a list of all jobs
  class Jobs < Collection

    def initialize(service)
      super(service, PATH_JOBS, entity_class=Job)

      @infinite_count = 0
    end

    def atom_entry_to_entity(entry)
      sid = entry["content"]["sid"]
      return Job.new(@service, sid)
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
      if args.has_key?(:exec_mode)
        raise ArgumentError.new("Cannot specify exec_mode for create. Use " +
                                    "create_oneshot or create_stream instead.")
      end

      args['search'] = query
      response = @service.request(:method => :POST,
                                  :resource => @resource,
                                  :body => args)
      sid = text_at_xpath("/response/sid", response.body)
      Job.new(@service, sid)
    end

    def create_oneshot(query, args={})
      args[:search] = query
      args[:exec_mode] = 'oneshot'
      response = @service.request(:method => :POST,
                                  :resource => @resource,
                                  :body => args)
      return response.body
    end

    def create_stream(query, args={})
      args["search"] = query
      response = @service.request(:method => :GET,
                                  :resource => @resource + ["export"],
                                  :query => args)
      return response.body
    end
  end
end
