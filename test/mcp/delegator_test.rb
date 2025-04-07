# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class DelegatorTest < MCPTest::TestCase
    module TestModule
      extend MCP::Delegator
    end

    def setup
      @dsl = TestModule
      @app = MCP::App.new
    end

    def teardown
      MCP::App.reset!
    end

    def test_tool_registration
      @dsl.tool("test_tool") do
        description "A test tool"
        argument :value, String, required: true, description: "Test value"
        call { |args| args[:value].to_s }
      end

      tools = MCP::App.new.list_tools[:tools]

      assert_equal 1, tools.size
      assert_equal "test_tool", tools.first[:name]
      assert_equal "A test tool", tools.first[:description]
    end

    def test_resource_registration
      @dsl.resource("test_resource") do
        name "test_resource"
        description "A test resource"
        call { "test content" }
      end

      resources = @app.list_resources[:resources]

      assert_equal 1, resources.size
      assert_equal "test_resource", resources.first[:name]
      assert_equal "A test resource", resources.first[:description]
    end

    def test_resource_template_registration
      @dsl.resource_template("content://{test_variable}") do
        name "test_template"
        description "A test resource"
        call { |args| "test content #{args[:test_variable]}" }
      end

      templates = @app.list_resource_templates[:resourceTemplates]

      assert_equal 1, templates.size
      assert_equal "test_template", templates.first[:name]
      assert_equal "A test resource", templates.first[:description]
    end

    def test_tool_block_execution
      @dsl.tool("echo") do
        description "Echo a message"
        argument :message, String, required: true, description: "Message to echo"
        call { |args| args[:message] }
      end

      result = @app.call_tool("echo", message: "hello").dig(:content, 0, :text)

      assert_equal "hello", result
    end

    def test_resource_block_execution
      @dsl.resource("content") do
        name "content"
        call { "test content" }
      end

      result = @app.read_resource("content").dig(:contents, 0, :text)

      assert_equal "test content", result
    end

    def test_resource_template_block_execution
      @dsl.resource_template("content://{test_variable}") do
        name "content"
        call { |args| "test content #{args[:test_variable]}" }
      end

      result = @app.read_resource("content://test").dig(:contents, 0, :text)

      assert_equal "test content test", result
    end

    def test_tool_registration_with_invalid_name
      assert_raises(ArgumentError) { @dsl.tool(nil) { "test" } }
      assert_raises(ArgumentError) { @dsl.tool("") { "test" } }
    end

    def test_resource_registration_with_invalid_name
      assert_raises(ArgumentError) { @dsl.resource(nil) { "test" } }
      assert_raises(ArgumentError) { @dsl.resource("") { "test" } }
    end

    def test_resource_template_registration_with_invalid_name
      assert_raises(ArgumentError) { @dsl.resource_template(nil) { "test" } }
      assert_raises(ArgumentError) { @dsl.resource_template("") { "test" } }
    end
  end
end
