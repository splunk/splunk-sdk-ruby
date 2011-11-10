require 'rest-client'

class Context
  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = "8089"
  DEFAULT_PROTOCOL = "https"


  def initialize(args)
    @args = args
    @token = nil
    @protocol = init_default('scheme', DEFAULT_PROTOCOL)
    @host = init_default('host', DEFAULT_HOST)
    @port = init_default('port', DEFAULT_PORT)
    @prefix = "#{@protocol}://#{@host}:#{@port}"
    @username = init_default('username', '')
    @password = init_default('password', '')
    @namespace = init_default('namespace', '')
    @headers = nil
  end

  def login
    response = post(url("/services/auth/login"), :username=>@username, :password=>@password)
    @headers = {'Authorization' => @token}
  end

  def logout

  end

  def post(path, body, params)
    RestClient.post(path, body, params) do |response, request, result, &block|

    end
  end

  def get(path, params)

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


