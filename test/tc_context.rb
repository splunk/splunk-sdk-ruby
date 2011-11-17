require "test/unit"
require "splunk-sdk/aloader"
require "splunk-sdk/context"

class TcContext < Test::Unit::TestCase
  NAMESPACE_ATOM = "atom:http://www.w3.org/2005/Atom"
  NAMESPACE_REST = "s:http://dev.splunk.com/ns/rest"
  NAMESPACE_OPENSEARCH = "opensearch:http://a9.com/-/spec/opensearch/1.1"

  #Test to make sure that certain endpoints return what looks like an ATOM feed
  def test_protocol
    c = Context.new(:username => 'admin', :password => 'sk8free', :protocol => 'https')
    c.login
    r = c.get('authentication/users')

    ns = [NAMESPACE_ATOM,NAMESPACE_REST,NAMESPACE_OPENSEARCH]

    doc = LibXML::XML::Parser.string(r).parse

    assert_equal(doc.root.name, 'feed')
    assert_equal(doc.find('atom:title', ns).length, 1)
    assert_equal(doc.find('atom:author', ns).length, 1)
    assert_equal(doc.find('atom:id', ns).length, 1)
    assert_equal(doc.find('atom:id', ns).length, 1)
  end

  #Test to make sure that we can login & logout
  def test_authentication

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

  def is_atom(body)
    body
  end

end