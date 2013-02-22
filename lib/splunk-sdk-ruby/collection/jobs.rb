#--
# Copyright 2011-2013 Splunk, Inc.
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

require 'delegate'

require_relative '../collection'
require_relative '../entity/job'

##
# Provides a class representing the collection of jobs in Splunk.
#

module Splunk
  ##
  # Class representing a search job in Splunk.
  #
  # +Jobs+ adds two additional methods to +Collection+ to start additional
  # kinds of search job. The basic +create+ method starts a normal,
  # asynchronous search job. The two new methods, +create_oneshot+ and
  # +create_stream+, creating oneshot and streaming searches, respectively,
  # which block until the search finishes and return the results directly.
  #
  class Jobs < Collection
    def initialize(service)
      super(service, PATH_JOBS, entity_class=Job)

      # +Jobs+ is one of the inconsistent collections where 0 means
      # list all, not -1.
      @infinite_count = 0
    end

    def atom_entry_to_entity(entry) # :nodoc:
      sid = entry["content"]["sid"]
      return Job.new(@service, sid)
    end

    ##
    # Creates an asynchronous search job.
    #
    # The search job requires a _query_, and takes a hash of other, optional
    # arguments, which are documented in the {Splunk REST documentation}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs - POST].
    #
    def create(query, args={})
      if args.has_key?(:exec_mode)
        raise ArgumentError.new("Cannot specify exec_mode for create. Use " +
                                    "create_oneshot or create_stream instead.")
      end

      args['search'] = query
      response = @service.request(:method => :POST,
                                  :resource => @resource,
                                  :body => args)
      sid = Splunk::text_at_xpath("/response/sid", response.body)
      Job.new(@service, sid)
    end

    ##
    # Creates a blocking search.
    #
    # The +create_oneshot+ method starts a search _query_, and any optional 
    # arguments specified in a hash (which are identical to those taken by 
    # +create+). It then blocks until the job finished, and returns the 
    # results, as transformed by any transforming search commands in _query_ 
    # (equivalent to calling the +results+ method on a +Job+).
    #
    # Returns: a stream readable by +ResultsReader+.
    #
    def create_oneshot(query, args={})
      args[:search] = query
      args[:exec_mode] = 'oneshot'
      response = @service.request(:method => :POST,
                                  :resource => @resource,
                                  :body => args)
      return response.body
    end

    ##
    # Creates a blocking search without transforming search commands.
    #
    # The +create_export+ method starts a search _query_, and any optional 
    # arguments specified in a hash (which are identical to those taken by 
    # +create+). It then blocks until the job is finished, and returns the 
    # events found by the job before any transforming search commands 
    # (equivalent to calling +events+ on a +Job+).
    #
    # Returns: a stream readable by +MultiResultsReader+.
    #
    def create_export(query, args={})
      args["search"] = query
      response = @service.request(:method => :GET,
                                  :resource => @resource + ["export"],
                                  :query => args)
      return ExportStream.new(response.body)
    end

    # Deprecated.
    def create_stream(query, args={}) # :nodoc:
      warn "[DEPRECATION] Jobs#create_stream is deprecated. Use Jobs#create_export instead."
      create_export(query, args)
    end
  end

  ##
  # Marks streams returned by the export endpoint for special handling.
  #
  # ResultsReader is supposed to handle streams from export differently
  # from those from other endpoints, so we use this delegator to mark them.
  #
  class ExportStream < Delegator
    def initialize(obj)
      super                  # pass obj to Delegator constructor, required
      @delegate = obj # store obj for future use
    end

    def __getobj__()
      @delegate
    end

    def __setobj__(obj)
      @delegate = obj
    end
  end
end
