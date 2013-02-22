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
# Provides a subclass of +Entity+ to represent stanzas in configuration files.
#

module Splunk
  ##
  # A class representing a stanza in a configuration file.
  #
  # +Stanza+ differs from +Entity+ only in providing a +length+ method
  # to count the number of keys in it.
  #
  class Stanza < Entity
    synonym "submit", "update"

    ##
    # Returns the number of elements in the stanza.
    #
    # The actual Atom feed returned will have extra fields giving metadata
    # about the stanza, which will not be counted.
    #
    # Returns: a nonnegative integer.
    #
    def length()
      @state["content"].
          reject() { |k| k.start_with?("eai") || k == "disabled" }.
          length()
    end
  end
end
