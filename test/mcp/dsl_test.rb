# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class DSLTest < MCPTest::TestCase
    def test_server_name
      server = with_dsl do
        name "test_server"
      end

      assert_equal "test_server", server.name
    end

    def test_server_version
      server = with_dsl do
        name "test_server" # required
        version "1.3.9"
      end

      assert_equal "1.3.9", server.version
    end

    def test_resource
      server = with_dsl do
        name "test_server" # required

        resource "hello://world.xml" do
          name "Hello World"
          description "A simple hello world message"
          call { "<greeting>Hello, World!</greeting>" }
          mime_type "application/xml"
        end
      end

      expected_resource = {
        uri: "hello://world.xml",
        name: "Hello World",
        description: "A simple hello world message",
        mimeType: "application/xml"
      }
      assert_equal [expected_resource], server.list_resources

      content = server.read_resource("hello://world.xml")
      assert_equal "<greeting>Hello, World!</greeting>", content
    end

    def test_resource_nil_uri
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          resource nil do
            name "Bad Resource"
            description "This should fail"
            call { "This should not run" }
          end
        end
      end

      assert_match(/Resource URI cannot be nil or empty/, error.message)
    end

    def test_resource_empty_uri
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          resource "" do
            name "Bad Resource"
            description "This should fail"
            call { "This should not run" }
          end
        end
      end

      assert_match(/Resource URI cannot be nil or empty/, error.message)
    end

    def test_resource_missing_name
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          resource "hello://missing-name.xml" do
            description "Resource without a name"
            call { "This should not run" }
          end
        end
      end

      assert_match(/Name must be provided/, error.message)
    end

    def test_resource_missing_handler
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          resource "hello://missing-handler.xml" do
            name "No Handler"
            description "Resource without a call handler"
          end
        end
      end

      assert_match(/Handler must be provided/, error.message)
    end

    def test_resource_template
      server = with_dsl do
        name "test_server" # required

        resource_template "hello://{user_name}.xml" do
          name "Hello User"
          description "A simple hello user message"
          mime_type "application/xml"
          call { |args| "<greeting>Hello, #{args[:user_name]}!</greeting>" }
        end
      end

      expected_resource_template = {
        uriTemplate: "hello://{user_name}.xml",
        name: "Hello User",
        description: "A simple hello user message",
        mimeType: "application/xml"
      }
      assert_equal [expected_resource_template], server.list_resource_templates

      content = server.read_resource("hello://alice.xml")
      assert_equal "<greeting>Hello, alice!</greeting>", content
    end

    def test_resource_template_nil_uri
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          resource_template nil do
            name "Bad Template"
            description "This should fail"
            call { |args| "This should not run" }
          end
        end
      end

      assert_match(/Resource URI template cannot be nil or empty/, error.message)
    end

    def test_resource_template_empty_uri
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          resource_template "" do
            name "Bad Template"
            description "This should fail"
            call { |args| "This should not run" }
          end
        end
      end

      assert_match(/Resource URI template cannot be nil or empty/, error.message)
    end

    def test_resource_template_missing_name
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          resource_template "hello://{id}.xml" do
            description "Template without a name"
            call { |args| "This should not run" }
          end
        end
      end

      assert_match(/Name must be provided/, error.message)
    end

    def test_tool
      server = with_dsl do
        name "test_server" # required

        tool "greet" do
          description "Greet someone by name"
          argument :name, String, required: true, description: "Name to greet"
          call do |args|
            "Hello, #{args[:name]}!"
          end
        end
      end

      expected_tool = {
        name: "greet",
        description: "Greet someone by name",
        inputSchema: {
          type: :object,
          properties: {
            name: {
              type: :string,
              description: "Name to greet"
            }
          },
          required: [:name]
        }
      }
      assert_equal [expected_tool], server.list_tools

      tool_result = server.call_tool("greet", name: "Alice")
      assert_equal "Hello, Alice!", tool_result
    end

    def test_tool_nil_name
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          tool nil do
            description "Bad Tool"
            argument :name, String
            call { |args| "This should not run" }
          end
        end
      end

      assert_match(/Tool name cannot be nil or empty/, error.message)
    end

    def test_tool_empty_name
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          tool "" do
            description "Bad Tool"
            argument :name, String
            call { |args| "This should not run" }
          end
        end
      end

      assert_match(/Tool name cannot be nil or empty/, error.message)
    end

    def test_tool_missing_handler
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          tool "missing_handler" do
            description "Tool without a handler"
            argument :name, String
          end
        end
      end

      assert_match(/Handler must be provided/, error.message)
    end

    def test_tool_argument_array_without_items
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          tool "invalid_array_arg" do
            description "Tool with invalid array argument"
            argument :names, Array
            call { |args| "Should not run" }
          end
        end
      end

      assert_match(/Must provide items or a block for array type/, error.message)
    end

    def test_tool_argument_without_type
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          tool "missing_type" do
            description "Tool with missing argument type"
            argument :name
            call { |args| "Should not run" }
          end
        end
      end

      assert_match(/Type required for simple arguments/, error.message)
    end

    def test_tool_unsupported_type
      error = assert_raises(ArgumentError) do
        with_dsl do
          name "test_server"
          tool "unsupported_type" do
            description "Tool with unsupported argument type"
            argument :timestamp, Time
            call { |args| "Should not run" }
          end
        end
      end

      assert_match(/Unsupported type: Time/, error.message)
    end

    private

    def with_dsl(&block)
      mod = Module.new do
        extend DSL
        instance_eval(&block)
      end

      DSL.build_server(mod)
    end
  end
end
