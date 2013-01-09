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
# Provides an +Entity+ subclass to represent search jobs.
#

require_relative '../entity'
require_relative '../namespace'

module Splunk
  ##
  # A class to represent a Splunk asynchronous search job.
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
    def initialize(service, sid)
      super(service, Splunk::namespace("global"), PATH_JOBS, sid)
      refresh() # Jobs don't return their state on creation
    end

    ##
    # Cancel this search job.
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
    # Issue a control request to this job.
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
      response = @service.request(
          :method => :GET,
          :resource => @resource + [sid, "events"],
          :body => args)
      return response.body
    end

    ##
    # Enable preview generation for this job.
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
    # Finalize this search job.
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
    def is_done()
      refresh()
      return fetch("isDone") == "1"
    end

    ##
    # Pause this search job.
    #
    # Use +unpause+ to resume.
    #
    # Returns: the +Job+.
    #
    def pause
      control(:action => "pause")
    end

    # Return a set of preview events from this +Job+.
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
      response = @service.request(:method => :GET,
                                  :resource => @resource +
                                      [sid, "results_preview"],
                                  :body => args)
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
    def sid
      fetch("sid")
    end

    ##
    # Returns the distribution over time of the events available so far.
    #
    # See the {REST docs for this call}[http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI/RESTsearch#search.2Fjobs.2F.7Bsearch_id.7D.2Ftimeline]
    # for more info on valid parameters and results.
    #
    # Returns: an +Array+ of +Hash+es describing each time bucket.
    #
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

    ##
    # Reset the time to live for this Job.
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
    # Set the time to live (TTL) of this +Job+.
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
