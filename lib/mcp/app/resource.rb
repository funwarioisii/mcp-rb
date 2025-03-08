# frozen_string_literal: true

module MCP
  class App
    module Resource
      # @rbs () -> Hash[untyped, untyped]
      def resources
        @resources ||= {}
      end

      class ResourceBuilder
        attr_reader :uri, :name, :description, :mime_type, :handler

        # @rbs (String?) -> void
        def initialize(uri)
          raise ArgumentError, "Resource URI cannot be nil or empty" if uri.nil? || uri.empty?
          @uri = uri
          @name = ""
          @description = ""
          @mime_type = "text/plain"
          @handler = nil
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

        # @rbs () -> Hash[untyped, untyped]?
        def to_resource_hash
          raise ArgumentError, "Handler must be provided" unless @handler
          raise ArgumentError, "Name must be provided" if @name.empty?

          {
            uri: @uri,
            name: @name,
            mime_type: @mime_type,
            description: @description,
            handler: @handler
          }
        end
      end

      # @rbs (String?) -> Hash[untyped, untyped]?
      def register_resource(uri, &block)
        builder = ResourceBuilder.new(uri)
        builder.instance_eval(&block)
        resource_hash = builder.to_resource_hash
        resources[uri] = resource_hash
        resource_hash
      end

      # @rbs (?cursor: nil | String, ?page_size: nil | Integer) -> Hash[untyped, untyped]
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
        }
      end

      # @rbs (String) -> Hash[untyped, untyped]?
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

      # @rbs (Hash[untyped, untyped]) -> Hash[untyped, untyped]
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
