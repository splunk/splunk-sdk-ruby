require 'rest-client'
require 'libxml'

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
    @headers = nil
  end

  def login
    response = post("/services/auth/login", {:username=>@username, :password=>@password})
    doc = LibXML::XML::Parser.string(response.to_s).parse
    @token = doc.find('//sessionKey').last.content
    @headers = {'Authorization' => "Splunk #{@token}"}
  end

  def logout

  end

  def post(path, body, params={})
    params.merge!(@headers) if !@headers.nil?
    RestClient.post(url(path), body, params) do |response, request, result, &block|
      #TODO: Need error handling
      response
    end
  end

  def get(path, params={})
    params.merge!(@headers) if !@headers.nil?
    puts url(path)
    RestClient.get(url(path), params) do |response, request, result, &block|
      #TODO: Need error handling
      response
    end
  end

  def delete(path, params)

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


end

c = Context.new(:username => 'admin', :password => 'sk8free', :protocol => 'http')
c.login
puts c.get('authentication/users')



