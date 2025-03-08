# frozen_string_literal: true

require_relative "resource"

module MCP
  class App
    module ResourceTemplate
      # @rbs () -> Hash[untyped, untyped]
      def resource_templates
        @resource_templates ||= {}
      end

      class ResourceTemplateBuilder
        attr_reader :uri_template, :name, :description, :mime_type, :handler

        # @rbs (String?) -> void
        def initialize(uri_template)
          raise ArgumentError, "Resource URI template cannot be nil or empty" if uri_template.nil? || uri_template.empty?
          @uri_template = uri_template
          @name = ""
          @description = ""
          @mime_type = "text/plain"
          @handler = nil
          @variables = extract_variables(uri_template)
        end

        # standard:disable Lint/DuplicateMethods,Style/TrivialAccessors
        # @rbs (String) -> void
        def name(value)
          @name = value
        end
        # standard:enable Lint/DuplicateMethods,Style/TrivialAccessors

        # standard:disable Lint/DuplicateMethods,Style/TrivialAccessors
        # @rbs (String) -> void
        def description(text)
          @description = text
        end
        # standard:enable Lint/DuplicateMethods,Style/TrivialAccessors

        # standard:disable Lint/DuplicateMethods,Style/TrivialAccessors
        def mime_type(value)
          @mime_type = value
        end
        # standard:enable Lint/DuplicateMethods,Style/TrivialAccessors

        # @rbs () -> Proc
        def call(&block)
          @handler = block
        end

        # @rbs () -> Hash[untyped, untyped]
        def to_resource_template_hash
          raise ArgumentError, "Name must be provided" if @name.empty?

          {
            uri_template: @uri_template,
            name: @name,
            mime_type: @mime_type,
            description: @description,
            handler: @handler,
            variables: @variables
          }
        end

        # Extract variables from a URI template
        # e.g., "channels://{channel_id}" => ["channel_id"]
        # @rbs (String) -> Array[untyped]
        def extract_variables(uri_template)
          variables = []
          uri_template.scan(/\{([^}]+)\}/) do |match|
            variables << match[0]&.to_sym
          end
          variables
        end

        # Creates a pattern for matching URIs against this template
        # @rbs () -> Regexp
        def to_pattern
          pattern_string = Regexp.escape(@uri_template).gsub(/\\\{[^}]+\\\}/) do |match|
            "([^/]+)"
          end
          Regexp.new("^#{pattern_string}$")
        end

        # Extract variable values from a concrete URI based on the template
        # e.g., template: "channels://{channel_id}", uri: "channels://123" => {"channel_id" => "123"}
        # @rbs (String) -> Hash[untyped, untyped]
        def extract_variable_values(uri)
          pattern = to_pattern
          match = pattern.match(uri)
          return {} unless match

          result = {}
          @variables.each_with_index do |var_name, index|
            result[var_name] = match[index + 1]
          end
          result
        end
      end

      # @rbs (String?) -> Hash[untyped, untyped]?
      def register_resource_template(uri_template, &block)
        builder = ResourceTemplateBuilder.new(uri_template)
        builder.instance_eval(&block)
        template_hash = builder.to_resource_template_hash
        resource_templates[uri_template] = template_hash
        template_hash
      end

      # Find a template that matches the given URI and extract variable values
      # @rbs (String) -> Array[untyped]
      def find_matching_template(uri)
        resource_templates.each do |template_uri, template|
          builder = ResourceTemplateBuilder.new(template_uri)
          variable_values = builder.extract_variable_values(uri)
          return [template, variable_values] unless variable_values.empty?
        end
        [nil, {}]
      end

      # @rbs (?cursor: nil | String, ?page_size: nil | Integer) -> Hash[untyped, untyped]
      def list_resource_templates(cursor: nil, page_size: nil)
        start_index = cursor&.to_i || 0
        values = resource_templates.values

        if page_size.nil?
          paginated = values[start_index..]
          next_cursor = nil
        else
          paginated = values[start_index, page_size]
          has_next = start_index + page_size < values.length
          next_cursor = has_next ? (start_index + page_size).to_s : nil
        end

        {
          resourceTemplates: paginated.map { |t| format_resource_template(t) },
          nextCursor: next_cursor
        }
      end

      private

      # @rbs (Hash[untyped, untyped]) -> Hash[untyped, untyped]
      def format_resource_template(template)
        {
          uriTemplate: template[:uri_template],
          name: template[:name],
          description: template[:description],
          mimeType: template[:mime_type]
        }
      end
    end
  end
end
