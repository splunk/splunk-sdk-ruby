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

# Ruby representations of Splunk namespaces as first class objects.
require 'singleton'

module Splunk
  def eai_acl_to_namespace(eai_acl)
    if eai_acl["sharing"] == "app" && eai_acl["app"] == ""
      # Special case: apps themselves are always referred to via the services/
      # path (i.e., the default namespace), but their eai:acl has sharing="app"
      # and app="".
      namespace("default")
    else
      namespace(eai_acl["sharing"], eai_acl["app"], eai_acl["owner"])
    end
  end

  def namespace(sharing="default", application=nil, user=nil)
    if sharing == "system"
      return SystemNamespace.instance
    elsif sharing == "global"
      return GlobalNamespace.instance
    elsif sharing == "user"
      if user.nil? or application.nil? or (user == "") or (application == "")
        raise ArgumentError.new("Must specify a user and application for user sharing.")
      else
        return UserNamespace.new(user, application)
      end
    elsif sharing == "app"
      if application.nil? or (application == "")
        raise ArgumentError.new("Must specify an application for application sharing")
      else
        return ApplicationNamespace.new(application)
      end
    elsif sharing == "default"
      return DefaultNamespace.instance
    end
  end

  # A mixin that fills the role of an abstract base class.
  module Namespace
    def is_proper?() end

    def to_path_fragment() end
  end

  class GlobalNamespace
    include Singleton
    include Namespace
    def is_proper?() true end
    def to_path_fragment() ["servicesNS", "nobody", "system"] end
  end

  class SystemNamespace
    include Singleton
    include Namespace
    def is_proper?() true end
    def to_path_fragment() ["servicesNS", "nobody", "system"] end
  end

  class DefaultNamespace
    include Singleton
    include Namespace
    def is_proper?() false end
    def to_path_fragment() ["services"] end
  end

  class ApplicationNamespace
    include Namespace
    attr_reader :application

    def initialize(application)
      @application = application
    end

    def ==(other)
      other.is_a?(ApplicationNamespace) && @application == other.application
    end

    def is_proper?()
      @application != "-"
    end

    def to_path_fragment()
      ["servicesNS", "nobody", @application]
    end
  end

  class UserNamespace
    include Namespace
    attr_reader :user, :application

    def initialize(user, application)
      @user = user
      @application = application
    end

    def ==(other)
      other.is_a?(UserNamespace) && @application == other.application &&
          @user == other.user
    end

    def is_proper?()
      (@application != "-") && (@user != "-")
    end

    def to_path_fragment()
      ["servicesNS", @user, @application]
    end
  end
end