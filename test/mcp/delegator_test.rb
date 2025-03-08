# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class DelegatorTest < MCPTest::TestCase
    # @rbs () -> bool
    def test_server_version
      server = build_test_server
      server.version "1.2.3"

      assert_equal "1.2.3", server.version

      initialize_response = initialize_server(server)
      assert_equal "1.2.3", initialize_response[:result][:serverInfo][:version]
    end

    # @rbs () -> bool
    def test_tool_registration
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.tool("test_tool") do
        description "A test tool"
        argument :value, String, required: true, description: "Test value"
        call { |args| args[:value].to_s }
      end

      tools = server.instance_variable_get(:@app).list_tools[:tools]

      assert_equal 1, tools.size
      assert_equal "test_tool", tools.first[:name]
      assert_equal "A test tool", tools.first[:description]
    end

    # @rbs () -> bool
    def test_resource_registration
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.resource("test_resource") do
        name "test_resource"
        description "A test resource"
        call { "test content" }
      end

      resources = server.instance_variable_get(:@app).list_resources[:resources]

      assert_equal 1, resources.size
      assert_equal "test_resource", resources.first[:name]
      assert_equal "A test resource", resources.first[:description]
    end

    # @rbs () -> bool
    def test_resource_template_registration
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.resource_template("content://{test_variable}") do
        name "test_template"
        description "A test resource"
        call { |args| "test content #{args[:test_variable]}" }
      end

      templates = server.instance_variable_get(:@app).list_resource_templates[:resourceTemplates]

      assert_equal 1, templates.size
      assert_equal "test_template", templates.first[:name]
      assert_equal "A test resource", templates.first[:description]
    end

    # @rbs () -> bool
    def test_tool_block_execution
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.tool("echo") do
        description "Echo a message"
        argument :message, String, required: true, description: "Message to echo"
        call { |args| args[:message] }
      end

      result = server.instance_variable_get(:@app).call_tool("echo", message: "hello").dig(:content, 0, :text)

      assert_equal "hello", result
    end

    # @rbs () -> bool
    def test_resource_block_execution
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.resource("content") do
        name "content"
        call { "test content" }
      end

      result = server.instance_variable_get(:@app).read_resource("content").dig(:contents, 0, :text)

      assert_equal "test content", result
    end

    # @rbs () -> bool
    def test_resource_template_block_execution
      server = Server.new(name: "test_server")
      initialize_server(server)

      server.resource_template("content://{test_variable}") do
        name "content"
        call { |args| "test content #{args[:test_variable]}" }
      end

      result = server.instance_variable_get(:@app).read_resource("content://test").dig(:contents, 0, :text)

      assert_equal "test content test", result
    end

    # @rbs () -> ArgumentError
    def test_tool_registration_with_invalid_name
      server = Server.new(name: "test_server")
      initialize_server(server)

      assert_raises(ArgumentError) { server.tool(nil) { "test" } }
      assert_raises(ArgumentError) { server.tool("") { "test" } }
    end

    # @rbs () -> ArgumentError
    def test_resource_registration_with_invalid_name
      server = Server.new(name: "test_server")
      initialize_server(server)

      assert_raises(ArgumentError) { server.resource(nil) { "test" } }
    end

    # @rbs () -> ArgumentError
    def test_resource_template_registration_with_invalid_name
      server = Server.new(name: "test_server")
      initialize_server(server)

      assert_raises(ArgumentError) { server.resource_template(nil) { "test" } }
    end
  end
end
