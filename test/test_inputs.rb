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
    highest_existing_port = input_collection
        .map() {|ent| ent.name}
        .select() {|name| name != nil}
        .map() do |name|
            if name.include?(":")
              name.split(":")[1]
            else
              name.name
            end
        end
    .map() {|p| Integer(p)}.max()
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
    assert_true(all_inputs.has_key?(port))

    tcp_inputs.delete(port)
    assert_false(tcp_inputs.has_key?(port))
    assert_false(all_inputs.has_key?(port))
  end

  def test_create_and_delete_tcp_raw_with_restrictToHost
    tcp_inputs = @service.inputs["tcp"]["raw"]
    all_inputs = @service.inputs["all"]

    port = get_free_port(tcp_inputs)
    name = "localhost:" + port
    @ports_to_delete << [["tcp", "raw"], name]

    input = tcp_inputs.create(port, :restrictToHost => "localhost")
    assert_equal(name, input.name)
    assert_equal("localhost", input["restrictToHost"])
    assert_true(tcp_inputs.has_key?(name))
    assert_true(all_inputs.has_key?(name))
    assert_false(tcp_inputs.has_key?(port))
    assert_false(all_inputs.has_key?(port))

    tcp_inputs.delete(name)
    assert_false(tcp_inputs.has_key?(name))
    assert_false(all_inputs.has_key?(name))
  end

  def test_update_on_restrictToHost_does_not_clear
    tcp_inputs = @service.inputs["tcp"]["raw"]
    all_inputs = @service.inputs["all"]

    port = get_free_port(tcp_inputs)
    name = "localhost:" + port
    @ports_to_delete << [["tcp", "raw"], name]

    input = tcp_inputs.create(port, :restrictToHost => "localhost")

    input.update({:sourcetype => "boris"})
    input.refresh()
    assert_equal("localhost", input["restrictToHost"])
    assert_true(tcp_inputs.has_key?(name))
    assert_true(all_inputs.has_key?(name))
  end

  def test_create_and_delete_udp
    udp_inputs = @service.inputs["udp"]
    all_inputs = @service.inputs["all"]

    port = get_free_port(udp_inputs)
    @ports_to_delete << [["udp"], port]

    input = udp_inputs.create(port)
    assert_equal(port, input.name)
    assert_true(udp_inputs.has_key?(port))
    assert_true(all_inputs.has_key?(port))

    udp_inputs.delete(port)
    assert_false(udp_inputs.has_key?(port))
    assert_false(all_inputs.has_key?(port))
  end

  def test_oneshot_input
    if !has_app_collection?(@service)
      print "Test requires sdk-app-collection. Skipping."
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
      index.delete()
    end
  end

  def test_oneshot_on_nonexistant_file
    name = temporary_name()
    assert_raises(Splunk::SplunkHTTPError) do
      @service.inputs["oneshot"].create(name)
    end
  end
end