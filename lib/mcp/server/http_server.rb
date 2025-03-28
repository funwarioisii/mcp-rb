# frozen_string_literal: true

require "falcon"
require "json"
require "rackup"
require_relative "base"

module MCP
  module Server
    # Rack App for MCP
    class McpRackApp
      def call(env)
        request = Rack::Request.new(env)

        case request.path
        when "/messages"
          handle_messages_request(request)
        when "/sse"
          handle_sse_request(request)
        else
          [404, {}, ["Not Found"]]
        end
      end

      private

      def handle_messages_request(request)
        [200, {}, ["Messages"]]
      end

      def handle_sse_request(request)
        [200, {}, ["SSE"]]
      end
    end

    # HTTP Server implementation for MCP using Server-Sent Events (SSE) with Falcon
    class FalconHttpServer < Base
      DEFAULT_HOST = "localhost"
      DEFAULT_PORT = 3001

      def initialize(name:, version: "0.1.0", host: DEFAULT_HOST, port: DEFAULT_PORT, transport: nil, **options)
        super(name: name, version: version)
        @host = host
        @port = port
      end

      def serve
        handler = Rackup::Handler.get(:falcon)
        handler.run McpRackApp.new, Port: @port.to_i
      end
    end
  end
end
