# frozen_string_literal: true

require_relative "../../test_helper"

module MCP
  class App
    class ResourceTemplateTest < MCPTest::TestCase
      def setup
        @app = App.new
      end

      def test_extract_variables
        @app.register_resource_template("/test/{param1}/{param2}") do
          name "test_template"
          call { |args| "#{args[:param1]}, #{args[:param2]}" }
        end

        template, values = @app.find_matching_template("/test/value1/value2")
        refute_nil template
        assert_equal({param1: "value1", param2: "value2"}, values)
      end

      def test_register_and_list_resource_templates
        @app.register_resource_template("/test/{param_1}") do
          name "test_resource template"
          description "A test resource template"
          call { |args| "test content #{args[:param_1]}" }
        end

        result = @app.list_resource_templates
        templates = result[:resourceTemplates]

        assert_equal 1, templates.length
        assert_equal "/test/{param_1}", templates.first[:uriTemplate]
        assert_equal "test_resource template", templates.first[:name]
        assert_equal "A test resource template", templates.first[:description]
        refute result.has_key?(:nextCursor)
      end

      def test_resource_templates_pagination
        10.times do |i|
          @app.register_resource_template("/test#{i}/{param_1}") do
            name "resource#{i}"
            call { |args| "content#{i} #{args[:param_1]}" }
          end
        end

        # Test without page_size (should return all resources)
        result = @app.list_resource_templates
        templates = result[:resourceTemplates]

        assert_equal 10, templates.length
        assert_equal "/test0/{param_1}", templates.first[:uriTemplate]
        assert_equal "resource0", templates.first[:name]
        refute result.has_key?(:nextCursor)

        # First page
        result = @app.list_resource_templates(page_size: 5)
        assert_equal 5, result[:resourceTemplates].length
        assert_equal "/test0/{param_1}", result[:resourceTemplates].first[:uriTemplate]
        assert_equal "resource0", result[:resourceTemplates].first[:name]
        assert_equal "5", result[:nextCursor]

        # Second page
        result = @app.list_resource_templates(page_size: 5, cursor: "5")
        assert_equal 5, result[:resourceTemplates].length
        assert_equal "/test5/{param_1}", result[:resourceTemplates].first[:uriTemplate]
        assert_equal "resource5", result[:resourceTemplates].first[:name]
        refute result.has_key?(:nextCursor)
      end

      def test_read_resource_template
        @app.register_resource_template("/test/{param_1}") do
          name "test_resource"
          call { |args| "test content #{args[:param_1]}" }
        end

        result = @app.read_resource("/test/value1")

        assert_equal "/test/value1", result[:contents].first[:uri]
        assert_equal "test content value1", result[:contents].first[:text]

        error = assert_raises(ArgumentError) { @app.read_resource("/non_existent") }
        assert_match(/Resource not found/, error.message)
      end
    end
  end
end
