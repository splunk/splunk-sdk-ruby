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

require_relative '../entity'

module Splunk
  ##
  # Class representing saved searches.
  #
  class SavedSearch < Entity
    ##
    #
    #
    def dispatch(args={})
      response = @service.request(:method => :POST,
                                  :namespace => @namespace,
                                  :resource => @resource + [name, "dispatch"],
                                  :body => args)
      sid = Splunk::text_at_xpath("//response/sid", response.body)
      return Job.new(@service, sid)
    end

    ##
    # Return a list of the jobs dispatched from this saved search.
    #
    # Returns: an +Array+ of +Job+ objects.
    #
    def history()
      response = @service.request(:namespace => @namespace,
                                  :resource => @resource + [@name, "history"])
      feed = AtomFeed.new(response.body)
      return feed.entries.map do |entry|
        Job.new(@service, entry["title"], entry)
      end
    end

    ##
    # Update the state of this saved search.
    #
    # See the method on Entity for documentation.
    #
    def update(args) # :nodoc:
      # Before Splunk 5.0, updating a saved search requires passing a +search+
      # argument, or it will return an error or set the search to empty. This is
      # fixed in 5.0, but while the 4.x series is supported, we set the search
      # field on args if it's not already set. This, of course, has a race
      # condition if someone else has set the search since the last time the
      # entity was refreshed.
      #
      # It would be nice to check if "search" is in the requiredFields list
      # on the entity, but that isn't always returned
      if !args.has_key?(:search) && !args.has_key?("search")
        args[:search] = fetch("search")
      end
      super(args)
    end
  end
end