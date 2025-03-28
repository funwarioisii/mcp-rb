# frozen_string_literal: true

require "addressable/template"
require_relative "resource"

module MCP
  class App
    module ResourceTemplate
      def resource_templates
        @resource_templates ||= {}
      end

      class ResourceTemplateBuilder
        attr_reader :uri_template, :name, :description, :mime_type, :handler

        def initialize(uri_template)
          raise ArgumentError, "Resource URI template cannot be nil or empty" if uri_template.nil? || uri_template.empty?
          @uri_template = uri_template
          @name = ""
          @description = ""
          @mime_type = "text/plain"
          @handler = nil
        end

        # standard:disable Lint/DuplicateMethods,Style/TrivialAccessors
        def name(value)
          @name = value
        end
        # standard:enable Lint/DuplicateMethods,Style/TrivialAccessors

        # standard:disable Lint/DuplicateMethods,Style/TrivialAccessors
        def description(text)
          @description = text
        end
        # standard:enable Lint/DuplicateMethods,Style/TrivialAccessors

        # standard:disable Lint/DuplicateMethods,Style/TrivialAccessors
        def mime_type(value)
          @mime_type = value
        end
        # standard:enable Lint/DuplicateMethods,Style/TrivialAccessors

        def call(&block)
          @handler = block
        end

        def to_resource_template_hash
          raise ArgumentError, "Name must be provided" if @name.empty?

          {
            uri_template: @uri_template,
            name: @name,
            mime_type: @mime_type,
            description: @description,
            handler: @handler,
          }
        end
      end

      def register_resource_template(uri_template, &block)
        builder = ResourceTemplateBuilder.new(uri_template)
        builder.instance_eval(&block)
        template_hash = builder.to_resource_template_hash
        template = Addressable::Template.new(uri_template)
        resource_templates[template] = template_hash
        template_hash
      end

      # Find a template that matches the given URI and extract variable values
      def find_matching_template(uri)
        resource_templates.each do |template, resource_template|
          variable_values = template.extract(uri)
          next if variable_values.nil? || variable_values.empty?

          return [resource_template, variable_values.transform_keys(&:to_sym)]
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
