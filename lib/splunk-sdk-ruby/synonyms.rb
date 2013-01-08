# :stopdoc:
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

##
# Easy creation of synonyms for methods.
#
# To make it easy to create Ruby's synonym sets (such as
# +has_key?+/+include?+/+member?+/etc. on +Hash+), we provide a mixin
# +Synonyms+ with one method, +synonym+. +synonym+ defines a new method
# named by its first parameter, with the same behavior as the method named
# by its second parameter.
#
# *Example:*
#
#     require 'synonyms'
#
#     class A
#       extend Synonyms
#       def f(...) ... end
#       synonym "g" "f"
#

module Synonyms
  # Make method _new_name_ a synonym for method _old_name_ on this class.
  #
  # Arguments:
  # * _new_name_: (+String+ or +Symbol+) The name of the method to create.
  # * _old_name_: (+String+ or +Symbol+) The name of the method to make the
  #   new method a synonym for.
  #
  private
  def synonym(new_name, old_name)
    define_method(new_name) do |*args, &block|
      old_method = old_name.intern
      send(old_method, *args, &block)
    end
  end
end
