# frozen_string_literal: true

require_relative "../../test_helper"

module MCP
  class App
    class ResourceTest < MCPTest::TestCase
      class TestApp
        include MCP::App::Resource
      end

      def setup
        @app = TestApp.new
      end

      def teardown
        TestApp.reset!
      end

      def test_register_and_list_resources
        TestApp.resource("/test") do
          name "test_resource"
          description "A test resource"
          call { "test content" }
        end

        result = @app.list_resources
        resources = result[:resources]

        assert_equal 1, resources.length
        assert_equal "/test", resources.first[:uri]
        assert_equal "test_resource", resources.first[:name]
        assert_equal "A test resource", resources.first[:description]
        refute result.has_key?(:nextCursor)
      end

      def test_resources_pagination
        10.times do |i|
          TestApp.resource("/test#{i}") do
            name "resource#{i}"
            call { "content#{i}" }
          end
        end

        # Test without page_size (should return all resources)
        result = @app.list_resources
        assert_equal 10, result[:resources].length
        assert_equal "/test0", result[:resources].first[:uri]
        assert_equal "resource0", result[:resources].first[:name]
        refute result.has_key?(:nextCursor)

        # First page
        result = @app.list_resources(page_size: 5)
        assert_equal 5, result[:resources].length
        assert_equal "/test0", result[:resources].first[:uri]
        assert_equal "resource0", result[:resources].first[:name]
        assert_equal "5", result[:nextCursor]

        # Second page
        result = @app.list_resources(page_size: 5, cursor: "5")
        assert_equal 5, result[:resources].length
        assert_equal "/test5", result[:resources].first[:uri]
        assert_equal "resource5", result[:resources].first[:name]
        refute result.has_key?(:nextCursor)
      end

      def test_read_resource
        TestApp.resource("/test") do
          name "test_resource"
          call { "test content" }
        end

        result = @app.read_resource("/test")

        assert_equal "/test", result[:contents].first[:uri]
        assert_equal "test content", result[:contents].first[:text]

        error = assert_raises(ArgumentError) { @app.read_resource("/non_existent") }
        assert_match(/Resource not found/, error.message)
      end

      def test_invalid_resource_registration
        error = assert_raises(ArgumentError) { TestApp.resource(nil) {} }
        assert_match(/Resource URI cannot be nil or empty/, error.message)

        error = assert_raises(ArgumentError) { TestApp.resource("") {} }
        assert_match(/Resource URI cannot be nil or empty/, error.message)

        error = assert_raises(ArgumentError) do
          TestApp.resource("/test") do
            # nameとhandlerが設定されていない
          end
        end
        assert_match(/Handler must be provided/, error.message)

        error = assert_raises(ArgumentError) do
          TestApp.resource("/test") do
            call { "test" }
            # nameが設定されていない
          end
        end
        assert_match(/Name must be provided/, error.message)
      end
    end
  end
end
