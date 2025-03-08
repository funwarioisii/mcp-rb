# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class ServerTest < MCPTest::TestCase
    # @rbs () -> bool
    def test_server_initialization
      server = Server.new(name: "test_server")
      assert_equal "test_server", server.name
      assert_equal "0.1.0", server.version
      refute server.initialized
    end

    # @rbs () -> bool
    def test_initialize_request
      server = Server.new(name: "test_server")
      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: MCP::Constants::PROTOCOL_VERSION,
          capabilities: {},
          clientInfo: {
            name: "test_client",
            version: "1.0.0"
          }
        },
        id: 1
      }

      response = server.send(:handle_request, request)
      assert_equal MCP::Constants::JSON_RPC_VERSION, response[:jsonrpc]
      assert_equal 1, response[:id]
      assert_equal MCP::Constants::PROTOCOL_VERSION, response[:result][:protocolVersion]
      assert_equal false, response[:result][:capabilities][:tools][:listChanged]
    end

    # @rbs () -> bool
    def test_initialize_with_unsupported_version
      server = Server.new(name: "test_server")
      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: "1999-01-01",
          capabilities: {}
        },
        id: 1
      }

      response = server.send(:handle_request, request)
      assert_equal "2.0", response[:jsonrpc]
      assert_equal 1, response[:id]
      assert response[:error]
      assert_equal "Unsupported protocol version", response[:error][:message]
    end

    # @rbs () -> bool
    def test_initialized_notification
      server = Server.new(name: "test_server")

      # First initialize
      init_request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: MCP::Constants::PROTOCOL_VERSION,
          capabilities: {}
        },
        id: 1
      }
      server.send(:handle_request, init_request)

      # Then send initialized notification
      init_notification = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::INITIALIZED,
        id: 2
      }
      response = server.send(:handle_request, init_notification)

      assert_nil response
    end

    # @rbs () -> bool
    def test_request_before_initialization
      server = Server.new(name: "test_server")
      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::TOOLS_LIST,
        id: 1
      }

      response = server.send(:handle_request, request)
      assert_equal(-32_002, response[:error][:code])
      assert_equal "Server not initialized", response[:error][:message]
    end

    # @rbs () -> MatchData
    def test_handle_call_tool
      server = Server.new(name: "test_server")
      initialize_server(server)

      # Register and call the tool
      server.tool("echo") do
        description "Echo a message"
        argument :message, String, required: true, description: "Message to echo"
        call { |args| args[:message] }
      end

      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: 1,
        method: MCP::Constants::RequestMethods::TOOLS_CALL,
        params: {
          name: "echo",
          arguments: {message: "hello"}
        }
      }

      response = server.send(:handle_request, request)

      assert_equal "2.0", response[:jsonrpc]
      assert_equal 1, response[:id]
      assert_match(/hello/, response[:result][:content].first[:text])
      refute response[:result][:isError]

      # Test error handling
      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: 2,
        method: MCP::Constants::RequestMethods::TOOLS_CALL,
        params: {
          name: "non_existent_tool",
          arguments: {}
        }
      }

      response = server.send(:handle_request, request)
      assert_equal "2.0", response[:jsonrpc]
      assert_equal 2, response[:id]
      assert response[:result][:isError]
      assert_match(/Tool not found/, response[:result][:content].first[:text])
    end

    # @rbs () -> bool
    def test_handle_ping
      server = Server.new(name: "test_server")

      request = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        method: MCP::Constants::RequestMethods::PING,
        id: 1
      }

      response = server.send(:handle_request, request)
      assert_equal "2.0", response[:jsonrpc]
      assert_equal 1, response[:id]
      assert_equal({}, response[:result])
    end
  end
end
