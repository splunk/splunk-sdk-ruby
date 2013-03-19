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

require_relative '../entity'

module Splunk
  class ModularInputKind < ReadOnlyEntity
    ##
    # Return a Hash of all the arguments support by this modular input kind.
    #
    # The keys in the Hash are the names of the arguments. The values are
    # additional Hashes giving the metadata about each argument. The possible
    # keys in those Hashes are +"title"+, +"description"+,
    # +"required_on_create``+, +"required_on_edit"+, +"data_type"+. Each value is
    # a string. It should be one of +"true"+ or +"false"+ for
    # +"required_on_create"+ and +"required_on_edit"+, and one of +"boolean"+,
    # +"string"+, or +"number"+ for +"data_type"+.
    #
    def arguments
      @state["content"]["endpoint"]["args"]
    end
  end
end
