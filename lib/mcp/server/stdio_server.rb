# frozen_string_literal: true

require_relative "base"
require_relative "client_connection"

module MCP
  module Server
    # StdioServer that implements MCP over stdin/stdout
    class StdioServer < Base
      # Serve requests over stdin/stdout
      # This method will block until the client disconnects or the server is stopped
      def serve
        client_connection = StdioClientConnection.new
        run_server(client_connection)
      end

      # Run the server loop with the given client connection
      # @param client_connection [ClientConnection] The connection to the client
      def run_server(client_connection)
        loop do
          next_message = client_connection.read_next_message
          break if next_message.nil? # Client closed the connection

          response = process_request(JSON.parse(next_message, symbolize_names: true))
          next unless response # Notifications don't return a response so don't send anything

          client_connection.send_message(JSON.generate(response))
        end
      end

      # Implementation of the stdio transport for the MCP server.
      # @see ClientConnection
      class StdioClientConnection
        include ClientConnection

        def initialize
          # Ensure output is flushed immediately
          $stdout.sync = true
        end

        def read_next_message
          message = $stdin.gets&.chomp
          if message.nil?
            close
          end

          message
        end

        def send_message(message)
          $stdout.puts(message)
        end

        def close
        end
      end
    end
  end
end
