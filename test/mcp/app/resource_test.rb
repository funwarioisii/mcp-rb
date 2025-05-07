# frozen_string_literal: true

require_relative "../../test_helper"

module MCP
  class App
    class ResourceTest < MCPTest::TestCase
      def setup
        @app = App.new
      end

      def test_register_and_list_resources
        @app.register_resource("/test") do
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
          @app.register_resource("/test#{i}") do
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
        @app.register_resource("/test") do
          name "test_resource"
          call { "test content" }
        end

        result = @app.read_resource("/test")

        assert_equal "/test", result[:contents].first[:uri]
        assert_equal "test content", result[:contents].first[:text]

        error = assert_raises(ArgumentError) { @app.read_resource("/non_existent") }
        assert_match(/Resource not found/, error.message)
      end
    end
  end
end
