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
# Ruby representations of Splunk namespaces.
#
# Splunk's namespaces give access paths to objects. Each application, user,
# search job, saved search, or other entity in Splunk has a namespace, and
# when you access an entity via the REST API, you include a namespace in your
# query. What entities are visible to your query depends on the namespace you
# use for the query.
#
# Some namespaces can contain wildcards or default values filled in by Splunk.
# We call such namespaces improper, since they cannot be the namespace of an
# entity, only a query. Namespaces which can be the namespace of an entity we
# call proper.
#
# We distinguish six kinds of namespace, each of which is represented by a
# separate class:
#
# * +DefaultNamespace+, used for queries where you want to use
#   whatever would be default for the user you are logged into Splunk as,
#   and is the namespace of applications (which themselves determine namespaces,
#   and so have to have a special one).
# * +GlobalNamespace+, which makes an entity visible anywhere in Splunk.
# * +SystemNamespace+, which is used for entities like users and roles that
#   are part of Splunk. Entities in the system namespace are visible anywhere
#   in Splunk.
# * +AppNamespace+, one per application installed in the Splunk instance.
# * +AppReferenceNamespace+, which is the namespace that applications themselves
#   live in. It differs from +DefaultNamespace+ only in that it is a proper
#   namespace.
# * The user namespaces, which are defined by a user _and_ an application.
#
# In the user and application namespaces, you can use +"-"+ as a wildcard
# in place of an actual user or application name.
#
# These are all represented in the Ruby SDK by correspondingly named classes:
# +DefaultNamespace+, +GlobalNamespace+, +SystemNamespace+, +AppNamespace+,
# and +UserNamespace+. Each of these have an empty mixin +Namespace+, so an
# instance of any of them will respond to +#is_a?(Namespace)+ with +true+.
#
# Some of these classes are singletons, some aren't, and to avoid confusion or
# having to remember which is which, you should create namespaces with the
# +namespace+ function.
#
# What namespace the +eai:acl+ fields in an entity map to is determined by what
# the path to that entity should be. In the end, a namespace is a way to
# calculate the initial path to access an entity. For example, applications all
# have +sharing="app"+ and +app=""+ in their +eai:acl+ fields, but their path
# uses the +services/+ prefix, so that particular combination, despite what it
# appears to be, is actually an +AppReferenceNamespace+.
#

require 'singleton'

module Splunk
  ##
  # Convert a hash of +eai:acl+ fields from Splunk's REST API into a namespace.
  #
  # _eai_acl_ should be a hash containing at least the key +"sharing"+, and,
  # depending on the value associated with +"sharing"+, possibly keys +"app"+
  # and +"owner"+.
  #
  # Returns: a +Namespace+.
  #
  def eai_acl_to_namespace(eai_acl)
    namespace(eai_acl["sharing"], eai_acl["app"], eai_acl["owner"])
  end

  ##
  # Create a +Namespace+.
  #
  # All the arguments are optional. The first argument, _sharing_, determines
  # what kind of namespace is produced. If it is omitted, a +DefaultNamespace+
  # is returned. It can have the values +"default"+, +"global"+, +"system"+,
  # +"user"+, or +"app"+.
  #
  # If _sharing_ is +"default"+, +"global"+, or +"system"+, the other two
  # arguments are ignored. If _sharing_ is +"app"+, only the first argument is
  # used to specify the application of the namespace. If _sharing_ is +"user"+,
  # then both arguments are used.
  #
  # If _sharing_ is +"app"+ but _app_ is +""+, it returns an
  # +AppReferenceNamespace+.
  #
  # Returns: a +Namespace+.
  #
  def namespace(sharing="default", app=nil, user=nil)
    if sharing == "system"
      return SystemNamespace.instance
    elsif sharing == "global"
      return GlobalNamespace.instance
    elsif sharing == "user"
      if user.nil? or app.nil? or (user == "") or (app == "")
        raise ArgumentError.new("Must specify a user and application for user sharing.")
      else
        return UserNamespace.new(user, app)
      end
    elsif sharing == "app"
      if app.nil?
        raise ArgumentError.new("Must specify an application for application sharing")
      elsif app == ""
        return AppReferenceNamespace.instance
      else
        return AppNamespace.new(app)
      end
    elsif sharing == "default"
      return DefaultNamespace.instance
    else
      raise ArgumentError.new("Unknown sharing value: #{sharing}")
    end
  end

  ##
  # A mixin that fills the role of an abstract base class.
  #
  # Namespaces have two methods: +is_proper?+ and +to_path_fragment+, and
  # can be compared for equality.
  #
  module Namespace
    ##
    # Is this a proper namespace?
    #
    # Returns: +true+ or +false+.
    #
    def is_proper?() end

    ##
    # Returns the URL prefix corresponding to this namespace.
    #
    # The prefix is returned as a list of strings. The strings
    # are _not_ URL encoded. You need to URL encode them when
    # you construct your URL.
    #
    # Returns: an +Array+ of +String+s.
    #
    def to_path_fragment() end
  end

  class GlobalNamespace # :nodoc:
    include Singleton
    include Namespace
    def is_proper?() true end
    def to_path_fragment() ["servicesNS", "nobody", "system"] end
  end

  class SystemNamespace # :nodoc:
    include Singleton
    include Namespace
    def is_proper?() true end
    def to_path_fragment() ["servicesNS", "nobody", "system"] end
  end

  class DefaultNamespace # :nodoc:
    include Singleton
    include Namespace
    def is_proper?() false end
    def to_path_fragment() ["services"] end
  end

  class AppReferenceNamespace # :nodoc:
    include Singleton
    include Namespace
    def is_proper?() true end
    def to_path_fragment() ["services"] end
  end

  class AppNamespace # :nodoc:
    include Namespace
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def ==(other)
      other.is_a?(AppNamespace) && @app == other.app
    end

    def is_proper?()
      @app != "-"
    end

    def to_path_fragment()
      ["servicesNS", "nobody", @app]
    end
  end

  class UserNamespace # :nodoc:
    include Namespace
    attr_reader :user, :app

    def initialize(user, app)
      @user = user
      @app = app
    end

    def ==(other)
      other.is_a?(UserNamespace) && @app == other.app &&
          @user == other.user
    end

    def is_proper?()
      (@app != "-") && (@user != "-")
    end

    def to_path_fragment()
      ["servicesNS", @user, @app]
    end
  end
end