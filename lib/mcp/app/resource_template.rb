# frozen_string_literal: true

require_relative "resource"

module MCP
  class App
    # Include this module in your app to add resource template functionality
    module ResourceTemplate
      def self.included(base)
        base.include(MCP::App::Resource)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def resource_templates
          @resource_templates ||= {}
        end

        def resource_template(resource_template, &block)
          resource_template = ResourceTemplateBuilder.new(resource_template, &block) if block_given?

          resource_template_hash = resource_template.to_h
          uri_template = resource_template_hash[:uri_template]

          raise ArgumentError, "Resource URI template cannot be nil or empty" if uri_template.nil? || uri_template.empty?
          raise ArgumentError, "Handler must be provided" if resource_template_hash[:handler].nil?
          raise ArgumentError, "Name must be provided" if resource_template_hash[:name].empty?

          resource_templates[uri_template] = resource_template_hash
        end

        def reset!
          @resource_templates = nil
        end
      end

      class ResourceTemplateBuilder
        attr_reader :uri_template, :handler

        def initialize(uri_template, &block)
          raise ArgumentError, "Resource URI template cannot be nil or empty" if uri_template.nil? || uri_template.empty?
          @uri_template = uri_template
          @name = ""
          @description = ""
          @mime_type = "text/plain"
          @handler = nil
          @variables = extract_variables(uri_template)
          instance_eval(&block) if block_given?
        end

        # standard:disable Style/TrivialAccessors
        def name(value)
          @name = value
        end

        def description(text)
          @description = text
        end

        def mime_type(value)
          @mime_type = value
        end
        # standard:enable Style/TrivialAccessors

        def call(&block)
          @handler = block
        end

        def to_h
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
        def extract_variables(uri_template)
          variables = []
          uri_template.scan(/\{([^}]+)\}/) do |match|
            variables << match[0]&.to_sym
          end
          variables
        end

        # Creates a pattern for matching URIs against this template
        def to_pattern
          pattern_string = Regexp.escape(@uri_template).gsub(/\\\{[^}]+\\\}/) do |match|
            "([^/]+)"
          end
          Regexp.new("^#{pattern_string}$")
        end

        # Extract variable values from a concrete URI based on the template
        # e.g., template: "channels://{channel_id}", uri: "channels://123" => {"channel_id" => "123"}
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

      def resource_templates
        self.class.resource_templates
      end

      # Find a template that matches the given URI and extract variable values
      def find_matching_template(uri)
        resource_templates.each do |template_uri, template|
          builder = ResourceTemplateBuilder.new(template_uri)
          variable_values = builder.extract_variable_values(uri)
          return [template, variable_values] unless variable_values.empty?
        end
        [nil, {}]
      end

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
        }.compact
      end

      private

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
