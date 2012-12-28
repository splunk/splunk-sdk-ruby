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
  # * `:namespace` - application namespace option.  'username:appname' (defaults to nil)
  # * `:key_file` - the full path to a SSL key file (defaults to nil)
  # * `:cert_file` - the full path to a SSL certificate file (defaults to nil)
  # * `:token` - a preauthenticated Splunk token (default to nil)
  #
  class Context
    # Fields on the context:
    # * `protocol`: 'https' or 'http' - String
    # * `host`: host where Splunk Server lives - String
    # * `port`: port number of the Splunk Server's management port - String
    # * `token`: the authentication token for this session (or `nil` if
    #   not logged in) - String.
    # * `username`: The username used to log in.
    # * `password`: The password used to log in.
    #
    attr_reader :scheme, :host, :port, :token,
                :username, :password

    def initialize(args)
      @token = args[:token] || nil
      @scheme = args[:scheme] || DEFAULT_SCHEME
      @host = args[:host] || DEFAULT_HOST
      @port = args[:port] || DEFAULT_PORT
      @username = args[:username]
      @password = args[:password]
      @namespace = args[:namespace]
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

      response = request(method=:POST,
                         scheme=nil,
                         host=nil,
                         port=nil,
                         namespace=namespace(),
                         resource=["auth", "login"],
                         query={},
                         headers={},
                         body={:username=>@username, :password=>@password})
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
    def logout
      @token = nil
    end

    #request(method :: (:GET|:POST|:DELETE),
    #                  scheme=:https :: (:http, :https),
    #                  host="localhost" :: String,
    #                  port=8089 :: Integer,
    #                  namespace=@default_namespace :: Namespace,
    #                  resource::[String], # e.g. "data/indexes"
    #                  query={} :: Hash-like Enumerable, # the URL's query
    #    headers={} :: Hash-like Enumerable,
    #    body={} :: Hash-like Enumerable)
    def request(method=:GET, scheme=nil, host=nil, port=nil,
                namespace=nil, resource=nil, query={}, headers={}, body={})
      # Make sure arguments are sane.
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
        request.body = body
      else
        request.body = URI.encode_www_form(body)
      end

      # Issue the request
      response = Net::HTTP::start(
          url.hostname, url.port,
          :use_ssl => url.scheme == 'https',
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
  end

end

    ## Make a POST REST call.
    ## _path_ is a partial path to the URL.  For example: 'authentication/roles'.
    ## If _body_ is a Hash, then all key/values of
    ## it are flattened, escaped, etc.  This is the typical use case.  _params_
    ## are not generally used (they are for lower level control).
    ##
    ## ==== Returns
    ##   The body of the response or throws SplunkHTTPError if the error >= 400
    ##
    ## ==== Examples - Issue a oneshot search and return the results in json
    ##  ctx = Splunk::Context.new(:username => 'admin', :password => 'password', :protocol => 'https')
    ##  ctx.login
    ##  args[:search] = "search error"
    ##  args[:exec_mode] = "oneshot"
    ##  args[:output_mode] = "json"
    ##  response = ctx.post("search/jobs", args)
    #def post(path, body, params={})
    #  # Warning - kludge alert!
    #  # because rest-client puts '[]' after repeated params, we need to
    #  # process them special by prepending them to any body we have.
    #  if body.is_a? Hash
    #    body.each do |k, v|
    #      if v.is_a? Array
    #        body = build_stream(flatten_params(body)).string
    #        break
    #      end
    #    end
    #  end
    #
    #  resource = create_resource(path, params)
    #  resource.post body, params do |response, request, result, &block|
    #    check_for_error_return(response)
    #    response
    #  end
    #end
    #
    ## Make a GET REST call.
    ## _path_ is a partial path to the URL.  For example: 'server/info'.
    ## _params_ are not generally used (they are for lower level control)
    ##
    ## ==== Returns
    ##   The body of the response or throws SplunkHTTPError if the error >= 400
    ##
    ## ==== Example - Get Server Information as an ATOM XML response
    ##   ctx = Splunk::Context.new(:username => 'admin', :password => 'password', :protocol => 'https')
    ##   ctx.login
    ##   response = ctx.get('server/info')
    ##
    ## ==== Example - Get Server Information, but conver the ATOM response into json and enable
    ## dot accessors.
    ##   ctx = Splunk::Context.new(:username => 'admin', :password => 'password', :protocol => 'https')
    ##   ctx.login
    ##   response = ctx.get('server/info')
    ##   record = AtomResponseLoader::load_text_as_record(response, MATCH_ENTRY_CONTENT, NAMESPACES)
    ##   puts record.content #Display the json
    #def get(path, params={})
    #  headers = {} #we don't allow additional headers for now
    #
    #  #flatten params onto the path
    #  fullpath = path
    #  if params.count > 0
    #    ext_path = build_stream(flatten_params(params)).string
    #    fullpath = path + '?' + ext_path
    #  end
    #
    #  resource = create_resource(fullpath, headers)
    #  resource.get headers do |response, request, result, &block|
    #    check_for_error_return(response)
    #    response
    #  end
    #end
    #
    ## Make a GET REST call and stream response to provided block
    ## _path_ is a partial path to the URL.  For example: 'server/info'.
    ## _params_ are not generally used (they are for lower level control)
    ## _block_ is passed the body in fragments as it is read from the socket
    ##
    ## ==== Returns
    ##   The response object or throws SplunkHTTPError if the error >= 400
    #def get_stream(path, params={}, &block)
    #  headers = {'Accept-Encoding' => ''} #we don't allow additional headers for now
    #
    #  #flatten params onto the path
    #  uri = path
    #  if params.count > 0
    #    ext_path = build_stream(flatten_params(params)).string
    #    uri << "?#{ext_path}"
    #  end
    #
    #  args = {:method         => :get,
    #          :headers        => headers.merge!(@headers),
    #          :url            => url(uri),
    #          :block_response => block}
    #  response = RestClient::Request::execute args
    #  check_for_error_return(response)
    #  response
    #end
    #
    ## Make a DELETE REST call.
    ## _path_ is a partial path to the URL.  For example 'authentication/users/rob',
    ## _params_ are not generally used (they are for lower level control)
    ##
    ## ==== Returns
    ##   The body of the response or throws SplunkHTTPError if the error >= 400
    ##
    ## ==== Example - Delete the user 'rob'
    ##   ctx = Splunk::Context.new(:username => 'admin', :password => 'password', :protocol => 'https')
    ##   ctx.login
    ##   response = ctx.delete('authentication/users/rob')
    ##
    ## TODO: Make this the same as 'get'.  In other words, params are not headers
    #def delete(path, params={})
    #  resource = create_resource(path, params)
    #  resource.delete params do |response, request, result, &block|
    #    check_for_error_return(response)
    #    response
    #  end
    #end
    #
    ## Open a socket to the Splunk HTTP server.  If the Context protocol is 'https', then
    ## an SSL wrapped socket is returned.  If the Context protocol is 'http', then a
    ## regular socket is returned.
    #def connect
    #  cn = TCPSocket.new @host, @port
    #  if protocol == 'https'
    #    ssl_context = OpenSSL::SSL::SSLContext.new
    #    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
    #    sslsocket = OpenSSL::SSL::SSLSocket.new(cn, ssl_context)
    #    sslsocket.sync_close = true
    #    sslsocket.connect
    #    return sslsocket
    #  end
    #  return cn
    #end
    #
    #def fullpath(path) # :nodoc:
    #  return path if path[0].eql?('/')
    #  return "/services/#{path}" if @namespace.nil?
    #  username, appname = @namespace.split(':')
    #  username = '-' if username == '*'
    #  appname = '-' if appname == '*'
    #  "/servicesNS/#{username}/#{appname}/#{path}"
    #end
    #
    #def init_default(key, deflt) # :nodoc:
    #  if @args.has_key?(key)
    #    return @args[key]
    #  end
    #  deflt
    #end
    #
    #def url(path) # :nodoc:
    #  "#{@prefix}#{fullpath(path)}"
    #end
    #
    #def create_resource(path, params={}) # :nodoc:
    #  params.merge!(@headers) if !@headers.nil?
    #  if @key_file.nil? or @cert_file.nil?
    #    resource = RestClient::Resource.new url(path)
    #  else
    #    # TODO(gba) File.read() before we're inside an OpenSSL call.
    #    resource = RestClient::Resource.new(
    #      url(path),
    #      :ssl_client_cert => OpenSSL::X509::Certificate.new(
    #        File.read(@cert_file)),
    #      :ssl_client_key => OpenSSL::PKey::RSA.new(
    #        File.read(@key_file)))
    #  end
    #  resource
    #end
    #
    #def check_for_error_return(response) # :nodoc:
    #  if response.code >= 400
    #    raise SplunkHTTPError.new(response)
    #  end
    #end
    #
    ## ripped directly from rest-client
    #def build_stream(params = nil) # :nodoc:
    #  r = flatten_params(params)
    #  stream = StringIO.new(r.collect do |entry|
    #    "#{entry[0]}=#{handle_key(entry[1])}"
    #  end.join("&"))
    #  stream.seek(0)
    #  stream
    #end
    #
    ## for UrlEncoded escape the keys
    #def handle_key key # :nodoc:
    #  URI.escape(key.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    #end
    #
    #def flatten_params(params, parent_key = nil) # :nodoc:
    #  result = []
    #  params.each do |key, value|
    #    calculated_key = if parent_key
    #                       "#{parent_key}[#{handle_key(key)}]"
    #                     else
    #                       handle_key(key)
    #                     end
    #    if value.is_a?(Hash)
    #      result += flatten_params(value, calculated_key)
    #    elsif value.is_a?(Array)
    #      result += flatten_params_array(value, calculated_key)
    #    else
    #      result << [calculated_key, value]
    #    end
    #  end
    #  result
    #end
    #
    #def flatten_params_array(value, calculated_key)  # :nodoc:
    #  result = []
    #  value.each do |elem|
    #    if elem.is_a?(Hash)
    #      result += flatten_params(elem, calculated_key)
    #    elsif elem.is_a?(Array)
    #      result += flatten_params_array(elem, calculated_key)
    #    else
    #      result << ["#{calculated_key}", elem]
    #    end
    #  end
    #  result
    #end

