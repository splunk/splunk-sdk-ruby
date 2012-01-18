# :stopdoc:
require "rubygems"
require "bundler/setup"

require "test/unit"
require "splunk-sdk-ruby/aloader"
require "splunk-sdk-ruby/context"
require "uuid"

$my_argv = ARGV.dup

rc_file = File.new(File.expand_path('~/.splunkrc'), "r")
$config = eval(rc_file.read)
$config[:protocol] = 'https' if !$config.key?(:protocol)

class TcContext < Test::Unit::TestCase
  NAMESPACE_ATOM = "atom:http://www.w3.org/2005/Atom"
  NAMESPACE_REST = "s:http://dev.splunk.com/ns/rest"
  NAMESPACE_OPENSEARCH = "opensearch:http://a9.com/-/spec/opensearch/1.1"
  PATH_USERS = "authentication/users"

  def random_uname
    UUID.new.generate
  end

  def assertHttp(allowed_error_codes)
    begin
      retval = yield
      retval
    rescue Splunk::SplunkHTTPError => e
      assert(allowed_error_codes.include?(e.code))
    rescue Exception => e
      p "SplunkHTTPError not caught.  Caught #{e.class} instead"
      assert(false)
    end
  end

  def is_atom(context, endpoint)
    ns = [NAMESPACE_ATOM,NAMESPACE_REST,NAMESPACE_OPENSEARCH]

    r = context.get(endpoint)

    doc = LibXML::XML::Parser.string(r).parse

    return false if doc.root.name != 'feed'
    return false if doc.find('atom:title', ns).length != 1
    return false if doc.find('atom:author', ns).length != 1
    return false if doc.find('atom:id', ns).length != 1

    true
  end

  #Test to make sure that certain endpoints return what looks like an ATOM feed
  def test_protocol
    c = Splunk::Context.new($config)
    c.login

    ['/services', PATH_USERS, 'search/jobs'].each do |endpoint|
      assert(is_atom(c,endpoint))
    end
  end

  #Test to make sure that we can login & logout
  def test_authentication
    #Test good login
    c = Splunk::Context.new($config)
    c.login

    #Test a get with the above context - should work
    assert(is_atom(c, PATH_USERS))

    #Test log out
    c.logout

    #Test a get with the above context - should fail
    assert_raise Splunk::SplunkHTTPError do
      is_atom(c, PATH_USERS)
    end

    #Test bad login (bad user)
    assert_raise Splunk::SplunkHTTPError do
      c = Splunk::Context.new(:username => 'baduser', :password => $config[:password], :protocol => $config[:protocol])
      c.login
    end

    #Test bad login (bad password)
    assert_raise Splunk::SplunkHTTPError do
      c = Splunk::Context.new(:username => $config[:username], :password => 'badpsw', :protocol => $config[:protocol])
      c.login
    end
  end

  def test_create_user
    begin
      c = Splunk::Context.new($config)
      c.login

      uname = random_uname

      #Cannot create a user w/o a role
      assertHttp [400] do
        c.post(PATH_USERS, :name => uname, :password => 'changeme')
      end

      #Create a test user
      response = c.post(PATH_USERS, :name => uname, :password => 'changeme', :roles => 'user')
      assert(response.code == 201)

      #Can't create the same user twice
      assertHttp [400] do
        c.post(PATH_USERS, :name => uname, :password => 'changeme', :roles => 'user')
      end

      #Connect as a newly created user
      user_ctx = Splunk::Context.new(:username => uname, :password => 'changeme', :protocol => 'https')
      user_ctx.login

      #Ensure that this user actually works
      assert(user_ctx.get("/services").code == 200)

      #This user cannot create new users
      assertHttp [403, 404] do
        user_ctx.post(PATH_USERS, :name => "barfo", :password => "killjoy", :roles => "user")
      end
    ensure
      #Test delete - clean up the random user
      response = c.delete(PATH_USERS + '/' + uname)
      assert(response.code == 200)
    end

  end

  def test_get_user
    c = Splunk::Context.new($config)
    c.login
    assert(c.get(PATH_USERS + '/admin').code == 200)
  end

  def test_get_users
    c = Splunk::Context.new($config)
    c.login
    assert(c.get(PATH_USERS).code == 200)
  end

  def test_edit_user
    uname = random_uname
    user_path = PATH_USERS + '/' + uname

    begin
      #login as admin
      c = Splunk::Context.new($config)
      c.login

      #create a random user
      response = c.post(PATH_USERS, :name => uname, :password => "changeme", :roles => 'user')
      assert(response.code == 201)

      userctx = Splunk::Context.new(:username => uname, :password => "changeme", :protocol => $config[:protocol])
      userctx.login

      #set the random user's default app to 'search'
      assert(userctx.post(user_path, :defaultApp => "search").code == 200)

      #set the random users default app to something random and watch it error out
      assertHttp [400] do
        userctx.post(user_path, :defaultApp => random_uname())
      end

      #set the random user's default app to ''
      assert(userctx.post(user_path, :defaultApp => "").code == 200)

      #set the random user's real name and email
      assert(userctx.post(user_path, :realname => "Bozo", :email => "email.me@now.com").code == 200)

      #set the random user's real name and email
      assert(userctx.post(user_path, :realname => "", :email => "").code == 200)

    ensure
      #Test delete - clean up the random user
      assert(c.delete(PATH_USERS + '/' + uname).code == 200)
    end
  end

def test_password
    uname = random_uname
    user_path = PATH_USERS + '/' + uname

    begin
      #login as admin
      c = Splunk::Context.new($config)
      c.login

      #create a random user
      response = c.post(PATH_USERS, :name => uname, :password => "changeme", :roles => 'user')
      assert(response.code == 201)

      userctx = Splunk::Context.new(:username => uname, :password => "changeme", :protocol => $config[:protocol])
      userctx.login

      #user changes their own password
      assert(userctx.post(user_path, :password => 'changed').code == 200)

      #user changes it again
      assert(userctx.post(user_path, :password => 'again').code == 200)

      #try to connect with the original password should error out
      userctx = Splunk::Context.new(:username => uname, :password => "changeme", :protocol => $config[:protocol])
      assert_raise Splunk::SplunkHTTPError do
        userctx.login
      end

      #admin changes it back and login should work
      assert(c.post(user_path, :password => 'changeme').code == 200)
      userctx = Splunk::Context.new(:username => uname, :password => "changeme", :protocol => $config[:protocol])
      userctx.login

    ensure
      #Test delete - clean up the random user
      assert(c.delete(PATH_USERS + '/' + uname).code == 200)
    end
  end

  def test_roles
    uname = random_uname
    user_path = PATH_USERS + '/' + uname

    begin
      #login as admin
      c = Splunk::Context.new($config)
      c.login

      #create a random user
      response = c.post(PATH_USERS, :name => uname, :password => "changeme", :roles => 'user')
      assert(response.code == 201)

      #admin updates to mutlipe roles
      assert(c.post(user_path, :roles => ["power","user"]).code == 200)

      #set back to a single role
      assert(c.post(user_path, :roles => 'user').code == 200)

      #fail adding unknown role
      assertHttp [400] do
        c.post(PATH_USERS, :roles => '_unknown__')
      end
    ensure
      #Test delete - clean up the random user
      assert(c.delete(PATH_USERS + '/' + uname).code == 200)
    end
  end

end