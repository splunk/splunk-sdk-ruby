require "rubygems"
require "bundler/setup"

require 'rest-client'
require 'libxml'
require 'openssl'
require 'pathname'
require 'stringio'
require 'netrc'
require 'socket'
#require 'uuid'

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
    attr_reader :protocol, :host, :port, :key_file, :cert_file, :token

    DEFAULT_HOST = "localhost"
    DEFAULT_PORT = "8089"
    DEFAULT_PROTOCOL = "https"

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
      #Note that this will throw it's own exception and we want to pass it up
      response = post("/services/auth/login", {:username=>@username, :password=>@password})
      begin
        doc = LibXML::XML::Parser.string(response.to_s).parse
        @token = doc.find('//sessionKey').last.content
        @headers = {'Authorization' => "Splunk #{@token}", 'User-Agent' => 'splunk-sdk-ruby/0.1'}
      rescue => e
        raise SplunkError, e.message
      end
    end

    # Log out of Splunk.  For now this simply nil's out the _token_ attribute
    def logout
      @token = nil
      @headers = {'Authorization' => "Splunk #{@token}", 'User-Agent' => 'splunk-sdk-ruby/0.1'}
    end

    def post(path, body, params={})
      #Warning - kludge alert!
      #because rest-client puts '[]' after repeated params, we need to process them special by
      #prepending them to any body we have
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

    #TODO: Make this the same as 'get'.  In other words, params are not headers
    def delete(path, params={})
      resource = create_resource(path, params)
      resource.delete params do |response, request, result, &block|
        check_for_error_return(response)
        response
      end
    end

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

    def fullpath(path)
      return path if path[0].eql?('/')
      return "/services/#{path}" if @namespace.nil?
      username, appname = @namespace.split(':')
      username = '-' if username == '*'
      appname = '-' if appname == '*'
      "/servicesNS/#{username}/#{appname}/#{path}"
    end

    def init_default(key, deflt)
      if @args.has_key?(key)
        return @args[key]
      end
      deflt
    end

    def url(path)
      "#{@prefix}#{fullpath(path)}"
    end

    def create_resource(path, params={})
      params.merge!(@headers) if !@headers.nil?
      if @key_file.nil? or @cert_file.nil?
        resource = RestClient::Resource.new url(path)
      else
        resource = RestClient::Resource.new(
            url(path),
            :ssl_client_cert => OpenSSL::X509::Certificate.new(File.read(@cert_file)),
            :ssl_client_key => OpenSSL::PKey::RSA.new(File.read(@key_file))
            #:verify_ssl => OpenSSL::SSL::VERIFY_PEER
        )
      end
      resource
    end

    def check_for_error_return(response)
      if response.code >= 400
        raise SplunkHTTPError.new(response)
      end
    end

    #ripped directly from rest-client
    def build_stream(params = nil)
      r = flatten_params(params)
      stream = StringIO.new(r.collect do |entry|
        "#{entry[0]}=#{handle_key(entry[1])}"
      end.join("&"))
      stream.seek(0)
      stream
    end

    # for UrlEncoded escape the keys
    def handle_key key
      URI.escape(key.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end

    def flatten_params(params, parent_key = nil)
      result = []
      params.each do |key, value|
        calculated_key = parent_key ? "#{parent_key}[#{handle_key(key)}]" : handle_key(key)
        if value.is_a? Hash
          result += flatten_params(value, calculated_key)
        elsif value.is_a? Array
          result += flatten_params_array(value, calculated_key)
        else
          result << [calculated_key, value]
        end
      end
      result
    end

    def flatten_params_array value, calculated_key
      result = []
      value.each do |elem|
        if elem.is_a? Hash
          result += flatten_params(elem, calculated_key)
        elsif elem.is_a? Array
          result += flatten_params_array(elem, calculated_key)
        else
          result << ["#{calculated_key}", elem]
        end
      end
      result
    end


  end
end
=begin
c = Context.new(:username => 'admin', :password => 'password', :protocol => 'https')
c.login
response = c.get('apps/local')
result = AtomResponseLoader::load_text_as_record(response)
p result.feed.title
p result.feed.author.name
result.feed.entry.each do |entry|
  e = AtomResponseLoader::record(entry)
  p e.content.eai_acl.perms.read
end
=end

=begin

c.post()

#login as admin
def random_uname
  UUID.new.generate
end

PATH_USERS = "authentication/users"

c = Context.new(:username => 'admin', :password => 'password')
c.login

#create a random user
uname = random_uname
p uname
response = c.post(PATH_USERS, :name => uname, :password => 'changeme', :roles => ['power','user'])
=end



