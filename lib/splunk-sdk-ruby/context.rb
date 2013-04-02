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
# Provides the +Context+ class, the basic class representing a connection to a 
# Splunk server. +Context+ is minimal, and only handles authentication and calls 
# to the REST API. For most uses, you will want to use its subclass +Service+, 
# which adds convenient methods to access the various collections and entities
# on Splunk.
#

require 'net/http'

require_relative 'splunk_http_error'
require_relative 'version'
require_relative 'xml_shim'
require_relative 'namespace'

module Splunk
  DEFAULT_HOST = 'localhost'
  DEFAULT_PORT = 8089
  DEFAULT_SCHEME = :https

  # Class encapsulating a connection to a Splunk server.
  #
  # This class is used for lower-level REST-based control of Splunk.
  # For most use, you will want to use +Context+'s subclass +Service+, which
  # provides convenient access to Splunk's various collections and entities.
  #
  # To use the +Context+ class, create a new +Context+ with a hash of arguments 
  # giving the details of the connection, and call the +login+ method on it:
  #
  #     context = Splunk::Context.new(:username => "admin",
  #                                   :password => "changeme").login()
  #
  # +Context+#+new+ takes a hash of keyword arguments. The keys it understands
  # are:
  #
  # * +:username+ - log in to Splunk as this user (no default)
  # * +:password+ - password to use when logging in (no default)
  # * +:host+ - Splunk host (e.g. "10.1.2.3") (default: 'localhost')
  # * +:port+ - the Splunk management port (default: 8089)
  # * +:protocol+ - either :https or :http (default: :https)
  # * +:namespace+ - a +Namespace+ object representing the default namespace for
  #   this context (default: +DefaultNamespace+)
  # * +:token+ - a preauthenticated Splunk token (default: +nil+)
  #
  # If you specify a token, you need not specify a username or password, nor
  # do you need to call the +login+ method.
  #
  # +Context+ provides three other important methods:
  #
  # * +connect+ opens a socket to the Splunk server.
  # * +request+ issues a request to the REST API.
  # * +restart+ restarts the Splunk server and handles waiting for it to come
  #   back up.
  #
  class Context
    def initialize(args)
      @token = args.fetch(:token, nil)
      @scheme = args.fetch(:scheme, DEFAULT_SCHEME).intern()
      @host = args.fetch(:host, DEFAULT_HOST)
      @port = Integer(args.fetch(:port, DEFAULT_PORT))
      @username = args.fetch(:username, nil)
      @password = args.fetch(:password, nil)
      # Have to use Splunk::namespace() or we will call the
      # local accessor.
      @namespace = args.fetch(:namespace,
                              Splunk::namespace(:sharing => "default"))
    end

    ##
    # The protocol used to connect.
    #
    # Defaults to +:https+.
    #
    # Returns: +:http+ or +:https+.
    #
    attr_reader :scheme

    ##
    # The host to connect to.
    #
    # Defaults to "+localhost+".
    #
    # Returns: a +String+.
    #
    attr_reader :host

    ##
    # The port to connect to.
    #
    # Defaults to +8089+.
    #
    # Returns: an +Integer+.
    #
    attr_reader :port

    ##
    # The authentication token on Splunk.
    #
    # If this +Context+ is not logged in, this is +nil+. Otherwise it is a
    # +String+ that is passed with each request.
    #
    # Returns: a +String+ or +nil+.
    #
    attr_reader :token

    ##
    # The username used to connect.
    #
    # If a token is provided, this field can be +nil+.
    #
    # Returns: a +String+ or +nil+.
    #
    attr_reader :username

    ##
    # The password used to connect.
    #
    # If a token is provided, this field can be +nil+.
    #
    # Returns: a +String+ or +nil+.
    #
    attr_reader :password

    ##
    # The default namespace used for requests on this +Context+.
    #
    # The namespace must be a +Namespace+ object. If a call to +request+ is
    # made without a namespace, this namespace is used for the request.
    #
    # Defaults to +DefaultNamespace+.
    #
    # Returns: a +Namespace+ object.
    #
    attr_reader :namespace

    ##
    # Opens a TCP socket to the Splunk HTTP server.
    #
    # If the +scheme+ field of this +Context+ is +:https+, this method returns
    # an +SSLSocket+. If +scheme+ is +:http+, a +TCPSocket+ is returned. Due to
    # design errors in Ruby's standard library, these two do not share the same
    # method names, so code written for HTTPS will not work for HTTP.
    #
    # Returns: an +SSLSocket+ or +TCPSocket+.
    #
    def connect()
      socket = TCPSocket.new(@host, @port)
      if scheme == :https
        ssl_context = OpenSSL::SSL::SSLContext.new()
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
        ssl_socket.sync_close = true
        ssl_socket.connect()
        return ssl_socket
      else
        return socket
      end
    end

    ##
    # Logs into Splunk and set the token field on this +Context+.
    #
    # The +login+ method assumes that the +Context+ has a username and password 
    # set. You cannot pass them as arguments to this method. On a successful 
    # login, the token field of the +Context+ is set to the token returned by 
    # Splunk, and all further requests to the server will send this token.
    #
    # If this +Context+ already has a token that is not +nil+, it is already
    # logged in, and this method is a nop.
    #
    # Raises +SplunkHTTPError+ if there is a problem logging in.
    #
    # Returns: the +Context+.
    #
    def login()
      if @token # If we're already logged in, this method is a nop.
        return
      end

      response = request(:namespace => Splunk::namespace(:sharing => "default"),
                         :method => :POST,
                         :resource => ["auth", "login"],
                         :query => {},
                         :headers => {},
                         :body => {:username=>@username, :password=>@password})
      # The response looks like:
      # <response>
      # <sessionKey>da950729652f8255c230afe37bdf8b97</sessionKey>
      # </response>
      @token = Splunk::text_at_xpath("//sessionKey", response.body)

      self
    end

    ##
    # Logs out of Splunk.
    #
    # This sets the @token attribute to +nil+.
    #
    # Returns: the +Context+.
    #
    def logout()
      @token = nil
      self
    end

    ##
    # Issues an HTTP(S) request to the Splunk instance.
    #
    # The +request+ method does not take a URL. Instead, it takes a hash of 
    # optional arguments specifying an action in the REST API. This avoids the 
    # problem knowing whether a given piece of data is URL encoded or not.
    #
    # The arguments are:
    #
    # * +method+: The HTTP method to use (one of +:GET+, +:POST+, or +:DELETE+;
    #   default: +:GET+).
    # * +namespace+: The namespace to request a resource from Splunk in. Must
    #   be a +Namespace+ object. (default: the value of +@namespace+ on
    #   this +Context+)
    # * +resource+: An array of strings specifying the components of the path
    #   to the resource after the namespace. The strings should not be URL
    #   encoded, as that will be handled by +request+. (default: [])
    # * +query+: A hash containing the values to be encoded as
    #   the query (the part following +?+) in the URL. Nothing should be URL
    #   encoded as +request+ will do the encoding. If you need to pass multiple
    #   values for the same key, insert them as an Array as the value of their
    #   key into the Hash, and they will be properly encoded as a sequence of
    #   entries with the same key. (default: {})
    # * +headers+: A hash containing the values to be encoded as headers. None
    #   should be URL encoded, and the +request+ method will automatically add
    #   headers for +User-Agent+ and Splunk authentication for you. Keys must
    #   be unique, so the values must be strings, not arrays, unlike for
    #   +query+. (default: {})
    # * +body+: Either a hash to be encoded as the body of a POST request, or
    #   a string to be used as the raw, already encoded body of a POST request.
    #   If you pass a hash, you can pass multiple values for the same key by
    #   encoding them as an Array, which will be properly set as multiple
    #   instances of the same key in the POST body. Nothing in the hash should
    #   be URL encoded, as +request+ will handle all such encoding.
    #   (default: {})
    #
    # If Splunk responds with an HTTP code 2xx, the +request+ method returns 
    # an HTTP response object (the import methods of which are +code+, 
    # +message+, and +body+, and +each+ to enumerate over the response 
    # headers). If the HTTP code is not 2xx, +request+ raises a 
    # +SplunkHTTPError+.
    #
    # *Examples:*
    #
    #     c = Splunk::connect(username="admin", password="changeme")
    #     # Get a list of the indexes in this Splunk instance.
    #     c.request(:namespace => Splunk::namespace(),
    #               :resource => ["data", "indexes"])
    #     # Create a new index called "my_new_index"
    #     c.request(:method => :POST,
    #               :resource => ["data", "indexes"],
    #               :body => {"name", "my_new_index"})
    #
    def request(args)
      method = args.fetch(:method, :GET)
      scheme = @scheme
      host = @host
      port = @port
      namespace = args.fetch(:namespace, @namespace)
      resource = args.fetch(:resource, [])
      query = args.fetch(:query, {})
      headers = args.fetch(:headers, {})
      body = args.fetch(:body, {})

      if method != :GET && method != :POST && method != :DELETE
        raise ArgumentError.new("Method must be one of :GET, :POST, or " +
                                    ":DELETE, found: #{method}")
      end

      if scheme && scheme != :http && scheme != :https
        raise ArgumentError.new("Scheme must be one of :http or :https, " +
                                    "found: #{scheme}")
      end

      if port && !port.is_a?(Integer)
        raise ArgumentError.new("Port must be an Integer, found: #{port}")
      end

      if !namespace.is_a?(Namespace)
        raise ArgumentError.new("Namespace must be a Namespace, " +
                                    "found: #{namespace}")
      end

      # Construct the URL for the request.
      url = ""
      url << "#{(scheme || @scheme).to_s}://"
      url << "#{host || @host}:#{(port || @port).to_s}/"
      url << (namespace.to_path_fragment() + resource).
          map {|fragment| URI::encode(fragment)}.
          join("/")

      return request_by_url(:url => url,
                            :method => method,
                            :query => query,
                            :headers => headers,
                            :body => body)
    end

    ##
    # Makes a request to the Splunk server given a prebuilt URL.
    #
    # Unless you are using a URL that was returned by the Splunk server
    # as part of an Atom feed, you should prefer the +request+ method, which
    # has much clearer semantics.
    #
    # The +request_by_url+ method takes a hash of arguments. The recognized 
    # arguments are:
    #
    # * +:url+: (a +URI+ object or a +String+) The URL, including authority, to
    #   make a request to.
    # * +:method+: (+:GET+, +:POST+, or +:DELETE+) The HTTP method to use.
    # * +query+: A hash containing the values to be encoded as
    #   the query (the part following +?+) in the URL. Nothing should be URL
    #   encoded as +request+ will do the encoding. If you need to pass multiple
    #   values for the same key, insert them as an +Array+ as the value of their
    #   key into the Hash, and they will be properly encoded as a sequence of
    #   entries with the same key. (default: {})
    # * +headers+: A hash containing the values to be encoded as headers. None
    #   should be URL encoded, and the +request+ method will automatically add
    #   headers for +User-Agent+ and Splunk authentication for you. Keys must
    #   be unique, so the values must be strings, not arrays, unlike for
    #   +query+. (default: {})
    # * +body+: Either a hash to be encoded as the body of a POST request, or
    #   a string to be used as the raw, already encoded body of a POST request.
    #   If you pass a hash, you can pass multiple values for the same key by
    #   encoding them as an +Array+, which will be properly set as multiple
    #   instances of the same key in the POST body. Nothing in the hash should
    #   be URL encoded, as +request+ will handle all such encoding.
    #   (default: {})
    #
    # If Splunk responds with an HTTP code 2xx, the +request_by_url+ method 
    # returns an HTTP response object (the import methods of which are +code+, 
    # +message+, and +body+, and +each+ to enumerate over the response 
    # headers). If the HTTP code is not 2xx, the +request_by_url+ method 
    # raises a +SplunkHTTPError+.
    #
    def request_by_url(args)
      url = args.fetch(:url)
      if url.is_a?(String)
        url = URI(url)
      end
      method = args.fetch(:method, :GET)
      query = args.fetch(:query, {})
      headers = args.fetch(:headers, {})
      body = args.fetch(:body, {})

      if !query.empty?
        url.query = URI.encode_www_form(query)
      end

      if method == :GET
        request = Net::HTTP::Get.new(url.request_uri)
      elsif method == :POST
        request = Net::HTTP::Post.new(url.request_uri)
      elsif method == :DELETE
        request = Net::HTTP::Delete.new(url.request_uri)
      end

      # Headers
      request["User-Agent"] = "splunk-sdk-ruby/#{VERSION}"
      request["Authorization"] = "Splunk #{@token}" if @token
      headers.each_entry do |key, value|
        request[key] = value
      end

      # Body
      if body.is_a?(String)
        # This case exists only for submitting an event to an index via HTTP.
        request.body = body
      else
        request.body = URI.encode_www_form(body)
      end

      # Issue the request.
      response = Net::HTTP::start(
          url.hostname, url.port,
          :use_ssl => url.scheme == 'https',
          # We don't support certificates.
          :verify_mode => OpenSSL::SSL::VERIFY_NONE
      ) do |http|
        http.request(request)
      end

      # Handle any errors.
      if !response.is_a?(Net::HTTPSuccess)
        raise SplunkHTTPError.new(response)
      else
        return response
      end
    end

    ##
    # Restarts this Splunk instance.
    #
    # The +restart+ method may be called with an optional timeout. If you pass 
    # a timeout, +restart+ will wait up to that number of seconds for the 
    # server to come back up before returning. If +restart+ did not time out, 
    # it leaves the +Context+ logged in when it returns.
    #
    # If the timeout is, omitted, the +restart+ method returns immediately, and
    # you will have to ascertain if Splunk has come back up yourself, for 
    # example with code like:
    #
    #     context = Context.new(...).login()
    #     context.restart()
    #     Timeout::timeout(timeout) do
    #         while !context.server_accepting_connections? ||
    #                 context.server_requires_restart?
    #             sleep(0.3)
    #         end
    #     end
    #
    # Returns: this +Context+.
    #
    def restart(timeout=nil)
      # Set a message saying that restart is required. Otherwise we have no
      # way of knowing if Splunk has actually gone down for a restart or not.
      request(:method => :POST,
              :namespace => Splunk::namespace(:sharing => "default"),
              :resource => ["messages"],
              :body => {"name" => "restart_required",
                        "value" => "Message set by restart method" +
                            " of the Splunk Ruby SDK"})

      # Make the actual restart request.
      request(:method => :POST,
              :resource => ["server", "control", "restart"])

      # Clear our old token, which will no longer work after the restart.
      logout()

      # If +timeout+ is +nil+, return immediately. If timeout is a positive
      # integer, wait for +timeout+ seconds for the server to come back up.
      if !timeout.nil?
        Timeout::timeout(timeout) do
          while !server_accepting_connections? || server_requires_restart?
            sleep(0.3)
          end
        end
      end

      # Return the +Context+.
      self
    end

    ##
    # Is the Splunk server accepting connections?
    #
    # Returns +true+ if the Splunk server is up and accepting REST API
    # connections; +false+ otherwise.
    #
    def server_accepting_connections?()
      begin
        # Can't use login, since it has short circuits
        # when @token != nil on the Context. Instead, make
        # a request directly.
        request(:resource => ["data", "indexes"])
      rescue Errno::ECONNREFUSED, EOFError, Errno::ECONNRESET
        return false
      rescue SplunkHTTPError
        # Splunk is up, because it responded with a proper HTTP error
        # that our SplunkHTTPError parser understood.
        return true
      else
        # Or the request worked, so we know that Splunk is up.
        return true
      end
    end

    ##
    # Is the Splunk server in a state requiring a restart?
    #
    # Returns +true+ if the Splunk server is down (equivalent to
    # +server_accepting_connections?+), or if there is a +restart_required+
    # message on the server; +false+ otherwise.
    #
    def server_requires_restart?()
      begin # We must have two layers of rescue, because the login in the
            # SplunkHTTPError rescue can also throw Errno::ECONNREFUSED.
        begin
          request(:resource => ["messages", "restart_required"])
          return true
        rescue SplunkHTTPError => err
          if err.code == 401
            # The messages endpoint requires authentication.
            logout()
            login()
            return server_requires_restart?()
          elsif err.code == 404
            return false
          else
            raise err
          end
        end
      rescue Errno::ECONNREFUSED, EOFError, Errno::ECONNRESET
        return true
      end
    end

  end
end