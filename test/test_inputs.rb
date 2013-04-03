require_relative 'test_helper'
require 'splunk-sdk-ruby'

include Splunk

class InputsTest < TestCaseWithSplunkConnection
  def setup
    super
    @ports_to_delete = []
  end

  def teardown
    @ports_to_delete.each do |spec|
      resource, name = spec
      inputs = @service.inputs
      resource.each do |r|
        inputs = inputs[r]
      end
      if inputs.has_key?(name)
        inputs.delete(name)
      end
      assert !inputs.has_key?(name)
    end
  end

  def get_free_port(input_collection)
    port_names = input_collection.map() {|ent| ent.name}
    proper_port_names = port_names.select() {|name| name != nil}
    ports = proper_port_names.map() do |name|
      if name.include?(":")
        name.split(":")[1]
      else
        name
      end
    end
    highest_existing_port = ports.map() {|p| Integer(p)}.max()

    if highest_existing_port == nil
      port = "10000"
    else
      port = (highest_existing_port + 1).to_s()
    end
  end

  def test_create_and_delete_tcp_raw
    tcp_inputs = @service.inputs["tcp"]["raw"]
    all_inputs = @service.inputs["all"]

    port = get_free_port(tcp_inputs)
    @ports_to_delete << [["tcp", "raw"], port]

    input = tcp_inputs.create(port)
    assert_equal(port, input.name)
    assert_true(tcp_inputs.has_key?(port))
    if @service.splunk_version[0] >= 5
      assert_true(all_inputs.has_key?(port))
    end

    tcp_inputs.delete(port)
    assert_false(tcp_inputs.has_key?(port))
    if @service.splunk_version[0] >= 5
      assert_false(all_inputs.has_key?(port))
    end
  end

  ##
  # Check that fetching with namespaces provided works.
  #
  def test_fetch_with_namespaces
    user_ns = Splunk::namespace(
        :sharing => "user",
        :app => "search",
        :owner => @splunkrc[:username]
    )
    begin
      user_udp_inputs = @service.inputs.fetch("udp", namespace=user_ns)
      port = get_free_port(user_udp_inputs)
      user_udp_inputs.create(port.to_s, :namespace => user_ns)
      user_udp_inputs.fetch(port.to_s, namespace=user_ns)
    ensure
      @service.inputs.fetch("udp", namespace=user_ns).delete(port.to_s)
    end
  end

  ##
  # Check that fetching a nonexistent input kind returns nil.
  #
  def test_fetch_nonexistent_input_kind
    assert_nil(@service.inputs[temporary_name()])
  end

  ##
  # Test that fetch resulting in server error raises SplunkHTTPError.
  def test_fetch_with_server_error
    new_service = Splunk::Service.new(@splunkrc)
    new_inputs = new_service.inputs()
    new_service.logout()
    assert_raise(SplunkHTTPError) do
      new_inputs["tcp"]
    end
  end

  def test_create_and_delete_tcp_raw_with_restrictToHost
    tcp_inputs = @service.inputs["tcp"]["raw"]

    port = get_free_port(tcp_inputs)
    name = "localhost:" + port
    @ports_to_delete << [["tcp", "raw"], name]

    input = tcp_inputs.create(port, :restrictToHost => "localhost")
    assert_equal(name, input.name)
    assert_equal("localhost", input["restrictToHost"])
    assert_true(tcp_inputs.has_key?(name))
    assert_false(tcp_inputs.has_key?(port))

    if @service.splunk_version[0] >= 5
      all_inputs = @service.inputs["all"]
      assert_true(all_inputs.has_key?(name))
      assert_false(all_inputs.has_key?(port))

    end

    tcp_inputs.delete(name)

    assert_false(tcp_inputs.has_key?(name))
    if @service.splunk_version[0] >= 5
      assert_false(all_inputs.has_key?(name))
    end
  end

  def test_update_on_restrictToHost_does_not_clear
    tcp_inputs = @service.inputs["tcp"]["raw"]

    port = get_free_port(tcp_inputs)
    name = "localhost:" + port
    @ports_to_delete << [["tcp", "raw"], name]

    input = tcp_inputs.create(port, :restrictToHost => "localhost")

    input.update({:sourcetype => "boris"})
    input.refresh()
    assert_equal("localhost", input["restrictToHost"])
    assert_true(tcp_inputs.has_key?(name))

    if @service.splunk_version[0] >= 5
      all_inputs = @service.inputs["all"]
      assert_true(all_inputs.has_key?(name))
    end
  end

  def test_create_and_delete_udp
    udp_inputs = @service.inputs["udp"]

    port = get_free_port(udp_inputs)
    @ports_to_delete << [["udp"], port]

    input = udp_inputs.create(port)
    assert_equal(port, input.name)
    assert_true(udp_inputs.has_key?(port))

    if @service.splunk_version[0] >= 5
      all_inputs = @service.inputs["all"]
      assert_true(all_inputs.has_key?(port))
    end

    udp_inputs.delete(port)
    assert_false(udp_inputs.has_key?(port))

    if @service.splunk_version[0] >= 5
      assert_false(all_inputs.has_key?(port))
    end
  end

  def test_oneshot_input
    if not has_test_data?(@service)
      fail("Install the SDK test data to test oneshot inputs.")
      return
    end

    install_app_from_collection("file_to_upload")

    index_name = temporary_name()
    index = @service.indexes.create(index_name)
    begin
      assert_eventually_true do
        index.refresh()
        index["disabled"] == "0"
      end

      event_count = Integer(index['totalEventCount'])
      path = path_in_app("file_to_upload", ["log.txt"])
      @service.inputs["oneshot"].create(path, :index => index_name)

      assert_eventually_true do
        index.refresh()
        Integer(index['totalEventCount']) == event_count + 4
      end
    ensure
      if @service.splunk_version[0] >= 5
        index.delete()
      end
    end
  end

  def test_oneshot_on_nonexistant_file
    name = temporary_name()
    assert_raises(Splunk::SplunkHTTPError) do
      @service.inputs["oneshot"].create(name)
    end
  end
end