# frozen_string_literal: true

module MCP
  module DSL
    class ServerBuilder
      def initialize
        @name = nil
        @version = nil
        @app = App.new
      end

      def build
        MCP::Server.new(
          app: @app,
          name: @name,
          version: @version
        )
      end

      # standard:disable Style/TrivialAccessors
      def name(name)
        @name = name
      end

      def version(version)
        @version = version
      end
      # standard:enable Style/TrivialAccessors

      def resource(uri, &block)
        @app.register_resource(uri, &block)
      end

      def resource_template(uri_template, &block)
        @app.register_resource_template(uri_template, &block)
      end

      def tool(name, &block)
        @app.register_tool(name, &block)
      end
    end
  end
end
