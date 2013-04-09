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

##
# Provides an +Entity+ subclass to represent search jobs.
#

require_relative '../entity'
require_relative '../namespace'

module Splunk
  ##
  # A class to represent a Splunk asynchronous search job.
  #
  # When you create a job, you need to wait for it to be ready before you can
  # interrogate it in an useful way. Typically, you will write something like
  #
  #     job = @service.jobs.create("search *")
  #     while !job.is_ready?
  #       sleep(0.2)
  #     end
  #     # Now the job is ready to use.
  #
  # The most important methods on +Job+ beyond those provided by +Entity+
  # are those that fetch results (+results+, +preview+), and those that control
  # the job's execution (+cancel+, +pause+, +unpause+, +finalize+).
  #
  # Note that jobs are created with preview disabled by default. You need to
  # call +enable_preview+ and wait for the field +"isPreviewEnabled"+ to be
  # +"1"+ before you will get anything useful from +preview+.
  #
  class Job < Entity
    def initialize(service, sid, state=nil)
      @sid = sid
      begin
        super(service, Splunk::namespace(:sharing => "global"), PATH_JOBS, sid, state)
      rescue EntityNotReady
        # Jobs may not be ready (and so cannot be refreshed) when they are
        # first created, so Entity#initialize may throw an EntityNotReady
        # exception. It's nothing to be concerned about for jobs.
      end
    end

    ##
    # Cancels this search job.
    #
    # Cancelling the job stops the search and deletes the results cache.
    #
    # Returns nothing.
    #
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

    ##
    # Issues a control request to this job.
    #
    # _args_ should be a hash with at least the key +:action+ (with a value such
    # as +"cancel"+ or +"setpriority"+).
    #
    # Returns: the +Job+.
    #
    def control(args) # :nodoc:
      @service.request(:method => :POST,
                       :namespace => @namespace,
                       :resource => @resource + [sid, "control"],
                       :body => args)
      self
    end

    ##
    # Returns the raw events found by this search job.
    #
    # These events are the data from the search pipeline before the first
    # "transforming" search command. This is the primary method for a client
    # to fetch a set of _untransformed_ events from a search job. This call is
    # only valid if the search has no transforming commands.
    #
    # If the job is not yet finished, this will return an empty set of events.
    #
    # See the {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fevents]
    # for more info on valid parameters and results.
    #
    # Returns: a stream that can be read with +ResultsReader+.
    #
    def events(args={})
      # Suppress segmentation (<sg> tags in the XML response) by default:
      if !args.has_key?(:segmentation)
        args[:segmentation] = "none"
      end
      response = @service.request(
          :method => :GET,
          :resource => @resource + [sid, "events"],
          :query => args)
      return response.body
    end

    ##
    # Enables preview generation for this job.
    #
    # Enabling previews may slow the search down considerably, but will
    # make the +preview+ method return events before the job is finished.
    #
    # Returns: the +Job+.
    #
    def enable_preview
      control(:action => "enablepreview")
    end

    ##
    # Finalizes this search job.
    #
    # Stops the search and provides whatever results have been obtained so far.
    # (retrievable via +results+).
    #
    # Returns: the +Job+.
    #
    def finalize
      control(:action => "finalize")
    end

    ##
    # Returns whether the search job is done.
    #
    # +is_done+ refreshes the +Job+, so its answer is always current.
    #
    # Returns: +true+ or +false+.
    #
    def is_done?()
      begin
        refresh()
        return fetch("isDone") == "1"
      rescue EntityNotReady
        return false
      end
    end

    ##
    # Returns whether the search job is ready.
    #
    # +is_ready+ refreshes the +Job+, so once the job is ready, you need
    # not call +refresh+ an additional time.
    #
    # Returns: +true+ or +false+.
    #
    def is_ready?()
      begin
        refresh()
        return true
      rescue EntityNotReady
        return false
      end
    end

    ##
    # Pauses this search job.
    #
    # Use +unpause+ to resume.
    #
    # Returns: the +Job+.
    #
    def pause
      control(:action => "pause")
    end

    # Returns a set of preview events from this +Job+.
    #
    # If the search job is finished, this method is identical to +results+.
    # Otherwise, it will return an empty results set unless preview is enabled
    # (for instance, by calling +enable_preview+).
    #
    # See the {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fresults_preview]
    # for more info on valid parameters and results.
    #
    # Returns: a stream readable by +ResultsReader+.
    #
    def preview(args={})
      # Suppress segmentation (<sg> tags in the XML response) by default:
      if !args.has_key?(:segmentation)
        args[:segmentation] = "none"
      end
      response = @service.request(:method => :GET,
                                  :resource => @resource +
                                      [sid, "results_preview"],
                                  :query => args)
      return response.body
    end

    ##
    # Returns search results for this job.
    #
    # These are the results after all processing from the search pipeline is
    # finished, including transforming search commands.
    #
    # The results set will be empty unless the job is done.
    #
    # Returns: a stream readable by +ResultsReader+.
    #
    def results(args={})
      response = @service.request(:resource => @resource + [sid, "results"],
                                  :body => args)
      return response.body
    end

    ##
    # Returns the search log for this search job.
    #
    # The search log is a syslog style file documenting the job.
    #
    # See the {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Fsearch.log]
    # for more info on valid parameters and results.
    #
    # Returns: a stream containing the log.
    #
    def searchlog(args={})
      response = @service.request(:resource => @resource + [sid, "search.log"],
                                  :body => args)
      return response.body
    end

    ##
    # Sets the priority of this search Job.
    #
    # _value_ can be 0-10, but unless the Splunk instance is running as
    # root or administrator, you can only reduce the priority.
    #
    # Arguments:
    # * _value_: an Integer from 0 to 10.
    #
    # Returns: the +Job+.
    #
    def set_priority(value)
      control(:action => "setpriority", :priority => value)
    end

    ##
    # Return the +Job+'s search id.
    #
    # Returns: a +String+.
    #
    attr_reader :sid

    ##
    # Returns the distribution over time of the events available so far.
    #
    # See the {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Ftimeline]
    # for more info on valid parameters and results.
    #
    # Each bucket is represented as a Hash with the following fields:
    # +:available_buckets+, +:event_count+, +:time_in_seconds+ (number of
    # seconds since the epoch), +:bucket_duration+ (how much time this bucket
    # covers), +:finished_scanning+ (is scanning for events in this bucket
    # complete), +:earliest_timezone+ and +:latest_timezone+ (which can be
    # different, for example when daylight savings time starts during a bucket's
    # duration), and +:time+ (a string representing the bucket's time in human
    # readable form).
    #
    # Returns: an +Array+ of Hashes describing each time bucket.
    #
    def timeline(args={})
      response = @service.request(:resource => @resource + [sid, "timeline"],
                                  :body => args)
      if $splunk_xml_library == :nokogiri
        doc = Nokogiri::XML(response.body)
        matches = doc.xpath("/timeline/bucket").map() do |bucket|
          {:available_buckets => Integer(bucket.attributes["a"].to_s),
           :event_count => Integer(bucket.attributes["c"].to_s),
           :time_in_seconds => Float(bucket.attributes["t"].to_s),
           :bucket_duration => Integer(bucket.attributes["d"].to_s),
           :finished_scanning => Integer(bucket.attributes["f"].to_s),
           :earliest_timezone => Integer(bucket.attributes["etz"].to_s),
           :latest_timezone => Integer(bucket.attributes["ltz"].to_s),
           :time => bucket.children.to_s}
        end
        return matches
      else
        doc = REXML::Document.new(response.body)
        matches = []
        matches = doc.elements.each("/timeline/bucket") do |bucket|
          {:available_buckets => Integer(bucket.attributes["a"]),
           :event_count => Integer(bucket.attributes["c"]),
           :time_in_seconds => Float(bucket.attributes["t"]),
           :bucket_duration => Integer(bucket.attributes["d"]),
           :finished_scanning => Integer(bucket.attributes["f"]),
           :earliest_timezone => Integer(bucket.attributes["etz"]),
           :latest_timezone => Integer(bucket.attributes["ltz"]),
           :time => bucket.children.join("")}
        end
        return matches
      end
    end

    ##
    # Resets the time to live for this Job.
    #
    # Calling touch resets the remaining time to live for the Job to its
    # original value.
    #
    # Returns: the +Job+.
    #
    def touch
      control(:action => "touch")
    end

    ##
    # Sets the time to live (TTL) of this +Job+.
    #
    # The time to live is a number in seconds saying how long the search job
    # should be on the Splunk system before being deleted.
    #
    # Returns: the +Job+.
    #
    def set_ttl(value)
      control(:action => "setttl", :ttl => value)
    end

    ##
    # Resumes execution of this Job.
    #
    # Returns: the +Job+.
    #
    def unpause
      control(:action => "unpause")
    end
  end
end
