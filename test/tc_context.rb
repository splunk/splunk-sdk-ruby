require "test/unit"
require "splunk-sdk/aloader"
require "splunk-sdk/context"

class TcContext < Test::Unit::TestCase
  NAMESPACE_ATOM = "atom:http://www.w3.org/2005/Atom"
  NAMESPACE_REST = "s:http://dev.splunk.com/ns/rest"
  NAMESPACE_OPENSEARCH = "opensearch:http://a9.com/-/spec/opensearch/1.1"

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

    ['/services', 'authentication/users', 'search/jobs'].each do |endpoint|
      assert(is_atom(c,endpoint))
    end
  end

  #Test to make sure that we can login & logout
  def test_authentication
    #Test good login
    c = Context.new(:username => 'admin', :password => 'sk8free', :protocol => 'https')
    c.login

    #Test a get with the above context - should work
    assert(is_atom(c, 'authentication/users'))

    #Test log out
    c.logout

    #Test a get with the above context - should fail
    assert_raise SplunkHTTPError do
      is_atom(c, 'authentication/users')
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

  def test_post

  end

  def test_get

  end

  def test_delete

  end

  def test_splunk_error

  end

  def test_deep_error

  end

  def test_create_user

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