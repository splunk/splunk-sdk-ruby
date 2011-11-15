require 'rest-client'
require 'libxml'
require 'openssl'
require './aloader'

class Context
  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = "8089"
  DEFAULT_PROTOCOL = "https"


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

  def login
    response = post("/services/auth/login", {:username=>@username, :password=>@password})
    doc = LibXML::XML::Parser.string(response.to_s).parse
    @token = doc.find('//sessionKey').last.content
    @headers = {'Authorization' => "Splunk #{@token}", 'User-Agent' => 'splunk-sdk-ruby/0.1'}
  end

  def logout
    @token = nil
  end

  def post(path, body, params={})
    resource = create_resource(path, params)
    resource.post body, params do |response, request, result, &block|
      #TODO: Need error handling
      response
    end
  end

  def get(path, params={})
    resource = create_resource(path, params)
    resource.get params do |response, request, result, &block|
      #TODO: Need error handling
      response
    end
  end

  def delete(path, params)
    resource = create_resource(path, params)
    resource.delete params do |response, request, result, &block|
      #TODO: Need error handling
      response
    end
  end


private
  def init_default(key, deflt)
    if @args.has_key?(key)
      return @args[key]
    end
    deflt
  end

  def fullpath(path)
    return path if path[0].eql?('/')
    return "/services/#{path}" if @namespace.nil?
    username, appname = @namespace.split(':')
    username = '-' if username == '*'
    appname = '-' if appname == '*'
    "/servicesNS/#{username}/#{appname}/#{path}"
  end

  def url(path)
    "#{@prefix}#{fullpath(path)}"
  end

  def create_resource(path, params)
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

end

c = Context.new(:username => 'admin', :password => 'sk8free', :protocol => 'http')
c.login
r = c.get('authentication/users')
al = AtomResponseLoader::load_text(r)
puts r
puts al



