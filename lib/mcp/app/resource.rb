# frozen_string_literal: true

module MCP
  class App
    # Include this module in your app to add resource functionality
    module Resource

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def resources
          @resources ||= {}
        end

        def resource(resource, &block)
          resource = ResourceBuilder.new(resource, &block) if block_given?

          resource_hash = resource.to_h
          uri = resource_hash[:uri]

          raise ArgumentError, "Resource URI cannot be nil or empty" if uri.nil? || uri.empty?
          raise ArgumentError, "Handler must be provided" unless resource_hash[:handler]
          raise ArgumentError, "Name must be provided" if resource_hash[:name].empty?

          resources[uri] = resource_hash
        end

        def reset!
          @resources = nil
        end
      end

      class ResourceBuilder
        attr_reader :uri, :handler

        def self.build(resource, &block)
          resource = new(resource, &block) if block_given?
          resource.to_h
        end

        def initialize(uri, &block)
          @uri = uri
          @name = ""
          @description = ""
          @mime_type = "text/plain"
          @handler = nil
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
            uri: @uri,
            name: @name,
            mime_type: @mime_type,
            description: @description,
            handler: @handler
          }
        end
      end

      def resources
        self.class.resources
      end

      def list_resources(cursor: nil, page_size: nil)
        start_index = cursor&.to_i || 0
        values = resources.values

        if page_size.nil?
          paginated = values[start_index..]
          next_cursor = nil
        else
          paginated = values[start_index, page_size]
          has_next = start_index + page_size < values.length
          next_cursor = has_next ? (start_index + page_size).to_s : nil
        end

        {
          resources: paginated.map { |r| format_resource(r) },
          nextCursor: next_cursor
        }.compact
      end

      def read_resource(uri)
        resource = resources[uri]

        # If no direct match, check if it matches a template
        if resource.nil? && respond_to?(:find_matching_template)
          template, variable_values = find_matching_template(uri)

          if template
            begin
              # Call the template handler with the extracted variables
              content = template[:handler].call(variable_values)
              return {
                contents: [{
                  uri: uri,
                  mimeType: template[:mime_type],
                  text: content
                }]
              }
            rescue => e
              raise ArgumentError, "Error reading resource from template: #{e.message}"
            end
          end
        end

        # If we still don't have a resource, raise an error
        raise ArgumentError, "Resource not found: #{uri}" unless resource

        begin
          content = resource[:handler].call
          {
            contents: [{
              uri: resource[:uri],
              mimeType: resource[:mime_type],
              text: content
            }]
          }
        rescue => e
          raise ArgumentError, "Error reading resource: #{e.message}"
        end
      end

      private

      def format_resource(resource)
        {
          uri: resource[:uri],
          name: resource[:name],
          description: resource[:description],
          mimeType: resource[:mime_type]
        }
      end
    end
  end
end
