require 'rexml/document'
require 'net/http'

require_relative 'version'

module Splunk
  DEFAULT_HOST = 'localhost'
  DEFAULT_PORT = 8089
  DEFAULT_SCHEME = :https

  # Low level access to the REST API.
  #
  # This class is used for lower level REST-based control of Splunk.
  # To get started by logging in, create a Context instance and call
  # `Context#login` on it.
  #
  # `Context#new` takes a hash of keyword arguments. The keys it understands
  # are:
  #
  # * `:username` - log in to Splunk as this user (no default)
  # * `:password` - password to use when logging in (no default)
  # * `:host` - Splunk host (e.g. "10.1.2.3") (defaults to 'localhost')
  # * `:port` - the Splunk management port (defaults to '8089')
  # * `:protocol` - either 'https' or 'http' (defaults to 'https')
  # * `:namespace` - application namespace option.  'username:appname'
  #     (defaults to nil)
  # * `:key_file` - the full path to a SSL key file (defaults to nil)
  # * `:cert_file` - the full path to a SSL certificate file (defaults to nil)
  # * `:token` - a preauthenticated Splunk token (default to nil)
  #
  class Context
    # Fields on the context:
    # * `scheme`: :https or :http - Symbol
    # * `host`: host where Splunk Server lives - String
    # * `port`: port number of the Splunk Server's management port - Integer
    # * `token`: the authentication token for this session (or `nil` if
    #   not logged in) - String.
    # * `username`: The username used to log in.
    # * `password`: The password used to log in.
    #
    attr_reader :scheme, :host, :port, :token,
                :username, :password, :namespace

    def initialize(args)
      @token = args.fetch(:token, nil)
      @scheme = args.fetch(:scheme, DEFAULT_SCHEME).intern()
      @host = args.fetch(:host, DEFAULT_HOST)
      @port = Integer(args.fetch(:port, DEFAULT_PORT))
      @username = args.fetch(:username, nil)
      @password = args.fetch(:password, nil)
      # Have to use Splunk::namespace() or we will call the
      # local accessor.
      @namespace = args.fetch(:namespace, Splunk::namespace())
    end

    # Open a TCP socket to the Splunk HTTP server.
    #
    # If the Context protocol is `https`, then an SSL wrapped socket is
    # returned.  If the Context protocol is `http`, then a regular socket
    # is returned.
    #
    def connect()
      socket = TCPSocket.new @host, @port
      if scheme == :https
        ssl_context = OpenSSL::SSL::SSLContext.new
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
        ssl_socket.sync_close = true
        ssl_socket.connect
        return ssl_socket
      else
        return socket
      end
    end

    # Login to Splunk. The _token_ attribute will be filled with the
    # Splunk authentication token upon successful login. If `@token` is not
    # `nil`, the context is taken to be already logged in, and this method
    # is a nop.
    #
    # Raises HTTPError if there is a problem logging in.
    #
    # Returns the Context.
    #
    def login()
      if @token # If we're already logged in, this method is a nop.
        return
      end

      response = request(:method => :POST,
                         :resource => ["auth", "login"],
                         :query => {},
                         :headers => {},
                         :body => {:username=>@username, :password=>@password})
      # The response looks like:
      # <response>
      # <sessionKey>da950729652f8255c230afe37bdf8b97</sessionKey>
      # </response>
      @token = text_at_xpath("//sessionKey", response.body)

      self
    end

    # Log out of Splunk.
    #
    # This sets the @token attribute to `nil`.
    #
    def logout()
      @token = nil
    end

    # Issue an HTTP request to the Splunk instance.
    #
    # `request` does not take a URL. Instead, it takes a number of optional
    # arguments from which it will construct a URL, then call request_by_url.
    # The arguments are:
    #
    # * `method`: The HTTP method to use (one of `:GET`, `:POST`, or `:DELETE`;
    #   default: `:GET`)
    # * `scheme`: `:http` or `:https` (defaults to the value of `@scheme` on
    #   this `Context`).
    # * `host`: The hostname to send the request to (defaults to the value of
    #   `@host` on this `Context`).
    # * `port`: The port on the host to connect to (default to the value of
    #   `@port` on this `Context`).
    # * `namespace`: The namespace to request a resource from Splunk in. Must
    #   by a `Namespace` object.
    #   (default: the value of `@namespace` on this `Context`).
    # * `resource`: An array of strings specifying the components of the path
    #   to the resource after the namespace. The strings should not be URL
    #   encoded, as that will be handled by `request`. (default: `[]`).
    # * `query`: A hash containing the values to be encoded as
    #   the query (the part following `?`) in the URL. Nothing should be URL
    #   encoded as `request` will do the encoding. If you need to pass multiple
    #   values for the same key, insert them as a list into the Hash, and they
    #   will be properly encoded as a sequence of entries with the same key.
    #   (default: `{}`)
    # * `headers`: A hash containing the values to be encoded as headers. None
    #   should be URL encoded, and the `request` method will automatically add
    #   headers for `User-Agent` and Splunk authentication for you. Keys must
    #   be unique, so the values must be strings, not arrays. (default: `{}`).
    # * `body`: Either a hash to be encoded as the body of a POST request, or
    #   a string to be used as the raw, already encoded body of a POST request.
    #   If you pass a hash, you can pass multiple values for the same key by
    #   encoding them as an Array, which will be properly set as multiple
    #   instances of the same key in the POST body. Nothing in the hash should
    #   be URL encoded, as `request` will handle all such encoding.
    #   (default: `{}`)
    #
    # If Splunk responds with an HTTP code 2xx, `request` returns an HTTP
    # response object (the import methods of which are `code`, `message`,
    # `body`, and `each` to enumerate over the response headers). If the HTTP
    # code is not 2xx, `request` raises a `SplunkHTTPError`.
    #
    # *Examples*
    #
    #     c = Splunk::connect(username=..., password=...)
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
      scheme = args.fetch(:scheme, @scheme)
      host = args.fetch(:host, @host)
      port = args.fetch(:port, @port)
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

      # Construct the URL for the request
      url = ""
      url << "#{(scheme || @scheme).to_s}://"
      url << "#{host || @host}:#{(port || @port).to_s}/"
      url << (namespace.to_path_fragment() + resource).
          map {|fragment| URI::encode(fragment)}.
          join("/")
      url = URI(url)
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

      # Issue the request
      response = Net::HTTP::start(
          url.hostname, url.port,
          :use_ssl => url.scheme == 'https',
          # We don't support certificates.
          :verify_mode => OpenSSL::SSL::VERIFY_NONE
      ) do |http|
        http.request(request)
      end

      # Handle any errors
      if !response.is_a?(Net::HTTPSuccess)
        raise SplunkHTTPError.new(response)
      else
        return response
      end
    end

    # Restart this Splunk instance.
    #
    # `restart` may be called with an optional timeout. If you pass a timeout,
    # `restart` will wait up to that number of seconds for the server to come
    # back up before returning. If `restart` did not time out, it leaves the
    # Context logged in when it returns.
    #
    # If the timeout is, omitted, `restart` returns immediately, and you will
    # have to ascertain if Splunk has come back up yourself, for example with
    # code like:
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
    # Returns this Context.
    #
    def restart(timeout=nil)
      if !timeout.nil?
        # If we're waiting for a timeout, set a message saying that restart is
        # required. It will be cleared when Splunk comes back up, but we
        # otherwise have no way to determine if Splunk has actually gone down.
        request(:method => :POST,
                :namespace => namespace(),
                :resource => ["messages"],
                :body => {"name" => "restart_required",
                          "value" => "Message set by restart method" +
                              " of the Splunk Ruby SDK"})
      end

      # Make the actual restart request.
      request(:resource => ["server", "control", "restart"])

      # Clear our old token, which will no longer work after the restart.
      logout()

      # If timeout is nil, return immediately. If timeout is a positive
      # integer, wait for `timeout` seconds for the server to come back
      # up.
      if !timeout.nil?
        Timeout::timeout(timeout) do
          while !server_accepting_connections? || server_requires_restart?
            sleep(0.3)
          end
        end
      end

      # Return the Context.
      self
    end

    # Is the Splunk server accepting connections?
    #
    # Returns true if the Splunk server is up and accepting REST API
    # connections; false otherwise.
    #
    def server_accepting_connections?()
      begin
        # Can't use login, since it has short circuits
        # when @token != nil on the Context. Instead, make
        # a request directly.
        request(:resource=>["data","indexes"])
      rescue Errno::ECONNREFUSED, EOFError
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

    # Is the Splunk server in a state requiring a restart?
    #
    # Returns true if the Splunk server is down (equivalent to
    # server_accepting_connections?), or if there is a `restart_required`
    # message on the server; false otherwise.
    #
    def server_requires_restart?()
      begin
        request(:resource => ["messages", "restart_required"])
        return true
      rescue Errno::ECONNREFUSED, EOFError
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
    end
  end
end