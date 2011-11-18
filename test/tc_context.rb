require "test/unit"
require "splunk-sdk/aloader"
require "splunk-sdk/context"
require "uuid"

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
    rescue SplunkHTTPError => e
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

    false if doc.root.name != 'feed'
    false if doc.find('atom:title', ns).length != 1
    false if doc.find('atom:author', ns).length != 1
    false if doc.find('atom:id', ns).length != 1

    true
  end

  #Test to make sure that certain endpoints return what looks like an ATOM feed
  def test_protocol
    c = Context.new(:username => 'admin', :password => 'sk8free', :protocol => 'https')
    c.login

    ['/services', PATH_USERS, 'search/jobs'].each do |endpoint|
      assert(is_atom(c,endpoint))
    end
  end

  #Test to make sure that we can login & logout
  def test_authentication
    #Test good login
    c = Context.new(:username => 'admin', :password => 'sk8free', :protocol => 'https')
    c.login

    #Test a get with the above context - should work
    assert(is_atom(c, PATH_USERS))

    #Test log out
    c.logout

    #Test a get with the above context - should fail
    assert_raise SplunkHTTPError do
      is_atom(c, PATH_USERS)
    end

    #Test bad login (bad user)
    assert_raise SplunkHTTPError do
      c = Context.new(:username => 'baduser', :password => 'sk8free', :protocol => 'https')
      c.login
    end

    #Test bad login (bad password)
    assert_raise SplunkHTTPError do
      c = Context.new(:username => 'admin', :password => 'badpsw', :protocol => 'https')
      c.login
    end
  end

  def test_create_user
    begin
      c = Context.new(:username => "admin", :password => 'sk8free', :protocol => 'https')
      c.login

      uname = random_uname

      #Cannot create a user w/o a role
      assertHttp [400] do
        c.post(PATH_USERS, :name => uname, :password => 'changeme')
      end

      #Create a test user
      assertHttp [201] do
        c.post(PATH_USERS, :name => uname, :password => 'changeme', :roles => 'user')
      end

      #Can't create the same user twice
      assertHttp [400] do
        c.post(PATH_USERS, :name => uname, :password => 'changeme', :roles => 'user')
      end

      #Connect as a newly created user
      user_ctx = Context.new(:username => uname, :password => 'changeme', :protocol => 'https')
      user_ctx.login

      #Ensure that this user actually works
      assertHttp [200] do
        user_ctx.get("/services")
      end

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

  end

  def test_get_users

  end

  def test_edit_user

  end

  def test_delete_user

  end

end