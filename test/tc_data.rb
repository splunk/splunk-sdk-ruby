require "test/unit"
require "ostruct"
require "splunk-sdk/aloader"

class TcData < Test::Unit::TestCase

  def test_elems
    assert_raise(ArgumentError) { assert_equal(AtomResponseLoader::load_text(""), nil) }

    assert_equal(AtomResponseLoader::load_text("<a></a>"), {'a' => nil})

    assert_equal(AtomResponseLoader::load_text("<a>1</a>"), {'a' => '1'})

    assert_equal(AtomResponseLoader::load_text("<a><b></b></a>"), {'a' => {'b' => nil}})

    assert_equal(AtomResponseLoader::load_text("<a><b>1</b></a>"), {'a' => {'b' => '1'}})

    assert_equal(AtomResponseLoader::load_text("<a><b></b><b></b></a>"),
                {'a' => {'b' => [nil, nil]}})

    assert_equal(AtomResponseLoader::load_text("<a><b>1</b><b>2</b></a>"),
                {'a' => {'b' => ['1','2']}})

    assert_equal(AtomResponseLoader::load_text("<a><b></b><c></c></a>"),
                {'a' => {'b' => nil, 'c' => nil}})

    assert_equal(AtomResponseLoader::load_text("<a><b>1</b><c>2</c></a>"),
                {'a' => {'b' => '1', 'c' => '2'}})

    assert_equal(AtomResponseLoader::load_text("<a><b><c>1</c></b></a>"),
                {'a' => {'b' => {'c' => '1'}}})

    assert_equal(AtomResponseLoader::load_text("<a><b><c>1</c></b><b>2</b></a>"),
                {'a' => {'b' => [{'c' => '1'}, '2']}})

  end

  def test_attrs
    assert_equal(AtomResponseLoader::load_text("<e a1='v1'/>"),
                {'e' => {'a1' => 'v1'}})

    assert_equal(AtomResponseLoader::load_text("<e a1='v1' a2='v2'/>"),
                {'e' => {'a1' => 'v1', 'a2' => 'v2'}})

    assert_equal(AtomResponseLoader::load_text("<e a1='v1'>v2</e>"),
                {'e' => {'$text' => 'v2', 'a1' => 'v1'}})

    assert_equal(AtomResponseLoader::load_text("<e a1='v1'><b>2</b></e>"),
                {'e' => {'a1' => 'v1', 'b' => '2'}})

    assert_equal(AtomResponseLoader::load_text("<e a1='v1'>v2<b>bv2</b></e>"),
                {'e' => {'a1' => 'v1', 'b' => 'bv2'}})

    assert_equal(AtomResponseLoader::load_text("<e a1='v1'><a1>v2</a1></e>"),
                {'e' => {'a1' => 'v1'}})

    assert_equal(AtomResponseLoader::load_text("<e1 a1='v1'><e2 a1='v1'>v2</e2></e1>"),
                {'e1' => {'a1' => 'v1', 'e2' => {'$text' => 'v2', 'a1' => 'v1'}}})
  end

  def test_dict
    assert_equal(AtomResponseLoader::load_text("
            <dict>
              <key name='n1'>v1</key>
              <key name='n2'>v2</key>
            </dict>"),
      {'n1' => 'v1', 'n2' => 'v2'})

    assert_equal(AtomResponseLoader::load_text("
          <content>
            <dict>
              <key name='n1'>v1</key>
              <key name='n2'>v2</key>
            </dict>
          </content>"),
    {'content' => {'n1' => 'v1', 'n2' => 'v2'}})

    assert_equal(AtomResponseLoader::load_text("
          <dict>
            <key name='n1'>v1</key>
            <key name='n2'>v2</key>
          </dict>"),
    {'n1' => 'v1', 'n2' => 'v2'})

    assert_equal(AtomResponseLoader::load_text("
          <content>
            <dict>
              <key name='n1'>
                <dict>
                  <key name='n1n1'>n1v1</key>
                </dict>
              </key>
              <key name='n2'>
                <dict>
                  <key name='n2n1'>n2v1</key>
                </dict>
              </key>
            </dict>
          </content>"),
    {'content' => {'n1' => {'n1n1' => 'n1v1'}, 'n2' => {'n2n1' => 'n2v1'}}})

    assert_equal(AtomResponseLoader::load_text("
          <content>
            <dict>
              <key name='n1'>
                <list>
                  <item>1</item><item>2</item><item>3</item><item>4</item>
                </list>
              </key>
            </dict>
          </content>"),
    {'content' => {'n1' => ['1','2','3','4']}})
  end

  def test_list
    assert_equal(AtomResponseLoader::load_text("
          <list>
            <item>1</item><item>2</item><item>3</item><item>4</item>
          </list>"),
    ['1','2','3','4'])

    assert_equal(AtomResponseLoader::load_text("
          <content>
              <list>
                <item>1</item><item>2</item><item>3</item><item>4</item>
              </list>
            </content>"),
    {'content' => ['1','2','3','4']})

    assert_equal(AtomResponseLoader::load_text("
          <content>
              <list>
                <item>
                  <list><item>1</item><item>2</item></list>
                </item>
                <item>
                  <list><item>3</item><item>4</item></list>
                </item>
              </list>
            </content>"),
    {'content' => [['1','2'], ['3','4']]})

    assert_equal(AtomResponseLoader::load_text("
          <content>
              <list>
                <item><dict><key name='n1'>v1</key></dict></item>
                <item><dict><key name='n2'>v2</key></dict></item>
                <item><dict><key name='n3'>v3</key></dict></item>
                <item><dict><key name='n4'>v4</key></dict></item>
              </list>
            </content>"),
    {'content' => [{'n1' => 'v1'}, {'n2' => 'v2'}, {'n3' => 'v3'}, {'n4' => 'v4'}]})
  end

  def test_real
    f = open("test/services.xml", 'r')
    result = AtomResponseLoader::load_text(f.read)

    assert(result.key?('feed'))
    assert(result['feed'].key?('author'))
    assert(result['feed'].key?('entry'))

    titles = result['feed']['entry'].collect {|item| item['title']}
    assert_equal(titles,
      ['alerts', 'apps', 'authentication', 'authorization', 'data',
       'deployment', 'licenser', 'messages', 'configs', 'saved',
       'scheduled', 'search', 'server', 'streams', 'broker', 'clustering',
       'masterlm'])

    f = open("test/services.server.info.xml", 'r')
    result = AtomResponseLoader::load_text(f.read)

    assert(result.key?('feed'))
    assert(result['feed'].key?('author'))
    assert(result['feed'].key?('entry'))
    assert_equal(result['feed']['title'], 'server-info')
    assert_equal(result['feed']['author']['name'], 'Splunk')
    assert_equal(result['feed']['entry']['content']['cpu_arch'], 'i386')
    assert_equal(result['feed']['entry']['content']['os_name'], 'Darwin')
    assert_equal(result['feed']['entry']['content']['os_version'], '10.8.0')
  end
end
