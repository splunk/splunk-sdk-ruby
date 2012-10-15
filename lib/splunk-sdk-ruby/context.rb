require 'rubygems'
#require 'bundler/setup'

require 'libxml'
require 'netrc'
require 'openssl'
require 'pathname'
require 'rest-client'
require 'socket'
require 'stringio'

require_relative 'aloader'
require_relative 'splunk_error'
require_relative 'splunk_http_error'


module Splunk
  ##
  # The <b>Binding Layer</b><br>.
  # This class is used for lower level REST-based control of Splunk.
  # To get started by logging in, create a Context instance and call
  # Context::login on it.
  class Context
    # 'https' or 'http' - String
    attr_reader :protocol

    # host were Splunk Server lives - String
    attr_reader :host

    # port number of the Splunk Server's management port - String
    attr_reader :port

    # the full path to a SSL key file - String
    attr_reader :key_file

    # the full path to a SSL certificate file - String
    attr_reader :cert_file

    # the authentication for this session.  nil if logged out. - String
    attr_reader :token

    DEFAULT_HOST = 'localhost'
    DEFAULT_PORT = '8089'
    DEFAULT_PROTOCOL = 'https'

    # Create an instance of a Context object used for logging in to Splunk
    #
    # ==== Attributes
    # +args+ - Valid args are listed below.  Note that they are all Strings:
    # * +:username+ - log in to Splunk as this user (no default)
    # * +:password+ - password for user 'username' (no default)
    # * +:host+ - Splunk host (e.g. '10.1.2.3') (defaults to 'localhost')
    # * +:port+ - the Splunk management port (defaults to '8089')
    # * +:protocol+ - either 'https' or 'http' (defaults to 'https')
    # * +:namespace+ - application namespace option.  'username:appname' (defaults to nil)
    # * +:key_file+ - the full path to a SSL key file (defaults to nil)
    # * +:cert_file+ - the full path to a SSL certificate file (defaults to nil)
    #
    # ==== Returns
    # instance of a Context class - must call login to use
    #
    # ==== Examples
    #   svc = Splunk::Context.new(:username => 'admin', :password => 'foo')
    #   svc = Splunk::Context.new(:username => 'admin', :password => 'foo', :host => '10.1.1.1', :port = '9999')
    #   svc.login
    def initialize(args)
      @args = args
      @token = nil
      @protocol = init_default(:protocol, DEFAULT_PROTOCOL)
      @host = init_default(:host, DEFAULT_HOST)
      @port = init_default(:port, DEFAULT_PORT)
      @prefix = "#{@protocol}://#{@host}:#{@port}"
      @username = init_default(:username, '')
      @password = init_default(:password, '')
      @namespace = init_default(:namespace, nil)
      @key_file = init_default(:key_file, nil)
      @cert_file = init_default(:cert_file, nil)
      @headers = nil
    end

    # Login to Splunk. The _token_ attribute will be filled with the
    # Splunk authentication token upon successful login.
    # Raises SplunkError if problem loggin in.
    def login
      # Note that this will throw it's own exception and we want to pass it up
      response = post(
        '/services/auth/login', {:username=>@username, :password=>@password})
      begin
        doc = LibXML::XML::Parser.string(response.to_s).parse
        @token = doc.find('//sessionKey')[-1].content
        # TODO(gba) Change '0.1' magic version below.
        @headers = {
          'Authorization' => "Splunk #{@token}",
          'User-Agent' => 'splunk-sdk-ruby/0.1'}
      rescue => e
        raise SplunkError, e.message
      end
    end

    # Log out of Splunk.  For now this simply nil's out the _token_ attribute
    def logout
      @token = nil
      # TODO(gba) Change '0.1' magic version below.
      @headers = {
        'Authorization' => "Splunk #{@token}",
        'User-Agent' => 'splunk-sdk-ruby/0.1'}
    end

    # Make a POST REST call.
    # _path_ is a partial path to the URL.  For example: 'authentication/roles'.
    # If _body_ is a Hash, then all key/values of
    # it are flattened, escaped, etc.  This is the typical use case.  _params_
    # are not generally used (they are for lower level control).
    #
    # ==== Returns
    #   The body of the response or throws SplunkHTTPError if the error >= 400
    #
    # ==== Examples - Issue a oneshot search and return the results in json
    #  ctx = Splunk::Context.new(:username => 'admin', :password => 'password', :protocol => 'https')
    #  ctx.login
    #  args[:search] = "search error"
    #  args[:exec_mode] = "oneshot"
    #  args[:output_mode] = "json"
    #  response = ctx.post("search/jobs", args)
    def post(path, body, params={})
      # Warning - kludge alert!
      # because rest-client puts '[]' after repeated params, we need to
      # process them special by prepending them to any body we have.
      if body.is_a? Hash
        body.each do |k, v|
          if v.is_a? Array
            body = build_stream(flatten_params(body)).string
            break
          end
        end
      end

      resource = create_resource(path, params)
      resource.post body, params do |response, request, result, &block|
        check_for_error_return(response)
        response
      end
    end

    # Make a GET REST call.
    # _path_ is a partial path to the URL.  For example: 'server/info'.
    # _params_ are not generally used (they are for lower level control)
    #
    # ==== Returns
    #   The body of the response or throws SplunkHTTPError if the error >= 400
    #
    # ==== Example - Get Server Information as an ATOM XML response
    #   ctx = Splunk::Context.new(:username => 'admin', :password => 'password', :protocol => 'https')
    #   ctx.login
    #   response = ctx.get('server/info')
    #
    # ==== Example - Get Server Information, but conver the ATOM response into json and enable
    # dot accessors.
    #   ctx = Splunk::Context.new(:username => 'admin', :password => 'password', :protocol => 'https')
    #   ctx.login
    #   response = ctx.get('server/info')
    #   record = AtomResponseLoader::load_text_as_record(response, MATCH_ENTRY_CONTENT, NAMESPACES)
    #   puts record.content #Display the json
    def get(path, params={})
      headers = {} #we don't allow additional headers for now

      #flatten params onto the path
      fullpath = path
      if params.count > 0
        ext_path = build_stream(flatten_params(params)).string
        fullpath = path + '?' + ext_path
      end

      resource = create_resource(fullpath, headers)
      resource.get headers do |response, request, result, &block|
        check_for_error_return(response)
        response
      end
    end

    # Make a DELETE REST call.
    # _path_ is a partial path to the URL.  For example 'authentication/users/rob',
    # _params_ are not generally used (they are for lower level control)
    #
    # ==== Returns
    #   The body of the response or throws SplunkHTTPError if the error >= 400
    #
    # ==== Example - Delete the user 'rob'
    #   ctx = Splunk::Context.new(:username => 'admin', :password => 'password', :protocol => 'https')
    #   ctx.login
    #   response = ctx.delete('authentication/users/rob')
    #
    # TODO: Make this the same as 'get'.  In other words, params are not headers
    def delete(path, params={})
      resource = create_resource(path, params)
      resource.delete params do |response, request, result, &block|
        check_for_error_return(response)
        response
      end
    end

    # Open a socket to the Splunk HTTP server.  If the Context protocol is 'https', then
    # an SSL wrapped socket is returned.  If the Context protocol is 'http', then a
    # regular socket is returned.
    def connect
      cn = TCPSocket.new @host, @port
      if protocol == 'https'
        ssl_context = OpenSSL::SSL::SSLContext.new
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        sslsocket = OpenSSL::SSL::SSLSocket.new(cn, ssl_context)
        sslsocket.sync_close = true
        sslsocket.connect
        return sslsocket
      end
      return cn
    end

    def fullpath(path) # :nodoc:
      return path if path[0].eql?('/')
      return "/services/#{path}" if @namespace.nil?
      username, appname = @namespace.split(':')
      username = '-' if username == '*'
      appname = '-' if appname == '*'
      "/servicesNS/#{username}/#{appname}/#{path}"
    end

    def init_default(key, deflt) # :nodoc:
      if @args.has_key?(key)
        return @args[key]
      end
      deflt
    end

    def url(path) # :nodoc:
      "#{@prefix}#{fullpath(path)}"
    end

    def create_resource(path, params={}) # :nodoc:
      params.merge!(@headers) if !@headers.nil?
      if @key_file.nil? or @cert_file.nil?
        resource = RestClient::Resource.new url(path)
      else
        # TODO(gba) File.read() before we're inside an OpenSSL call.
        resource = RestClient::Resource.new(
          url(path),
          :ssl_client_cert => OpenSSL::X509::Certificate.new(
            File.read(@cert_file)),
          :ssl_client_key => OpenSSL::PKey::RSA.new(
            File.read(@key_file)))
      end
      resource
    end

    def check_for_error_return(response) # :nodoc:
      if response.code >= 400
        raise SplunkHTTPError.new(response)
      end
    end

    # ripped directly from rest-client
    def build_stream(params = nil) # :nodoc:
      r = flatten_params(params)
      stream = StringIO.new(r.collect do |entry|
        "#{entry[0]}=#{handle_key(entry[1])}"
      end.join("&"))
      stream.seek(0)
      stream
    end

    # for UrlEncoded escape the keys
    def handle_key key # :nodoc:
      URI.escape(key.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end

    def flatten_params(params, parent_key = nil) # :nodoc:
      result = []
      params.each do |key, value|
        calculated_key = if parent_key
                           "#{parent_key}[#{handle_key(key)}]"
                         else
                           handle_key(key)
                         end
        if value.is_a?(Hash)
          result += flatten_params(value, calculated_key)
        elsif value.is_a?(Array)
          result += flatten_params_array(value, calculated_key)
        else
          result << [calculated_key, value]
        end
      end
      result
    end

    def flatten_params_array(value, calculated_key)  # :nodoc:
      result = []
      value.each do |elem|
        if elem.is_a?(Hash)
          result += flatten_params(elem, calculated_key)
        elsif elem.is_a?(Array)
          result += flatten_params_array(elem, calculated_key)
        else
          result << ["#{calculated_key}", elem]
        end
      end
      result
    end
  end
end
