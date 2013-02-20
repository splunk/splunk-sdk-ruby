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

module Splunk
  ##
  # Exception thrown when fetching from an entity returns HTTP code 204.
  #
  # This primarily comes up with jobs. When a job is not yet ready, fetching
  # it from the server returns code 204, and we want to handle it specially.
  #
  class EntityNotReady < StandardError
  end
end
