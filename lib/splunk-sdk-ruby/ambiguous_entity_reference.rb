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

module Splunk
  ##
  # Exception thrown when a request found multiple matching entities.
  #
  # An entity is uniquely defined by its name plus its namespace, so when you
  # try to fetch an entity by name alone, it is possible to get multiple
  # results. In that case, this error is thrown by methods that are supposed 
  # to return only a single entity.
  #
  class AmbiguousEntityReference < StandardError
  end
end