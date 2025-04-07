# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class ServerTest < MCPTest::TestCase
    def teardown
      App.reset!
    end

    def test_server_version
      prepare_server(version: "1.2.3")

      assert_equal "1.2.3", @server.version

      initialize_response = initialize_server(@server)
      assert_equal "1.2.3", initialize_response[:result][:serverInfo][:version]
    end

    def test_basic_server_info
      prepare_server(name: "special_test_server", version: "1.4.1")

      assert_equal "special_test_server", @server.name
      assert_equal "1.4.1", @server.version
    end

    def test_knows_if_initialized
      start_server

      refute @server.initialized?

      send_message a_valid_initialize_request
      send_message a_valid_initialized_notification

      assert @server.initialized?
    end

    def test_responds_with_server_info_on_initialize
      start_server(name: "special_test_server", version: "1.4.1")

      response = send_message a_valid_initialize_request

      expected = {
        name: "special_test_server",
        version: "1.4.1"
      }
      assert_equal expected, response[:result][:serverInfo]
    end

    def test_supports_tools_without_list_changed
      start_server

      response = send_message a_valid_initialize_request

      expected = {listChanged: false}
      assert_equal expected, response[:result][:capabilities][:tools]
    end

    def test_supports_resources_without_sub_capabilities
      start_server

      response = send_message a_valid_initialize_request

      expected = {
        subscribe: false,
        listChanged: false
      }
      assert_equal expected, response[:result][:capabilities][:resources]
    end

    def test_does_not_support_prompts
      start_server

      response = send_message a_valid_initialize_request

      refute_includes response[:result][:capabilities].keys, :prompts
    end

    def test_does_not_support_logging
      start_server

      response = send_message a_valid_initialize_request

      refute_includes response[:result][:capabilities].keys, :logging
    end

    def test_returns_nothing_on_initialized_notification
      start_server
      send_message a_valid_initialize_request

      response = send_message a_valid_initialized_notification

      assert_nil response
    end

    def test_does_not_allow_unsupported_protocol_version
      start_server

      request = json_rpc_message(
        method: Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: "1999-01-01",
          capabilities: {},
          clientInfo: {
            name: "test_client",
            version: "1.0.0"
          }
        }
      )
      response = send_message request

      expected_error = {
        code: Constants::ErrorCodes::INVALID_PARAMS,
        message: "Unsupported protocol version",
        data: {supported: ["2024-11-05"], requested: "1999-01-01"}
      }
      assert_equal expected_error, response[:error]
    end

    def test_does_not_allow_non_ping_requests_before_initialize
      start_server

      request = json_rpc_message(
        method: Constants::RequestMethods::TOOLS_LIST
      )
      response = send_message request

      expected_error = {
        code: Constants::ErrorCodes::NOT_INITIALIZED,
        message: "Server not initialized"
      }
      assert_equal expected_error, response[:error]
    end

    def test_allows_ping_requests_before_initialize
      start_server

      response = send_message a_valid_ping_request

      assert_successful_response response
    end

    def test_client_closing_connection
      start_initialized_server

      send_message nil

      assert_server_has_stopped
    end

    def test_does_not_allow_non_json_messages
      start_server

      response = send_message "not json"

      expected_error = {
        code: Constants::ErrorCodes::PARSE_ERROR,
        message: "Invalid JSON: unexpected token at 'not json'"
      }
      assert_equal expected_error, response[:error]
    end

    def test_does_not_allow_non_json_rpc_messages
      start_server
      non_json_rpc_message = {"some_key" => "some_value"}.to_json

      response = send_message non_json_rpc_message

      expected_error = {
        code: Constants::ErrorCodes::INVALID_REQUEST,
        message: "Invalid request",
        data: {
          errors: ["object at root is missing required properties: jsonrpc, method"]
        }
      }
      assert_equal expected_error, response[:error]
    end

    def test_does_not_allow_messages_with_unknown_method
      start_initialized_server

      request = json_rpc_message(
        method: "unknown_method"
      )
      response = send_message request

      expected_error = {
        code: Constants::ErrorCodes::METHOD_NOT_FOUND,
        message: "Unknown method: unknown_method"
      }
      assert_equal expected_error, response[:error]
    end

    def test_does_not_allow_messages_with_invalid_params
      start_initialized_server

      request = json_rpc_message(
        method: Constants::RequestMethods::RESOURCES_READ,
        params: {
          invalid_param: "invalid_value"
        }
      )
      response = send_message request

      expected_error = {
        code: Constants::ErrorCodes::INVALID_PARAMS,
        message: "Invalid params",
        data: {
          errors: ["object at `/params` is missing required properties: uri"]
        }
      }
      assert_equal expected_error, response[:error]
    end

    def test_reports_internal_errors
      start_server

      @server.stub(:handle_request, proc { raise "Something went wrong" }) do
        response = send_message a_valid_ping_request

        assert response[:error]
        assert_equal Constants::ErrorCodes::INTERNAL_ERROR, response[:error][:code]
        assert_includes response[:error][:message], "Something went wrong"
      end
    end

    private

    # Assumed to be run inside a Fiber
    class MockClientConnection
      include Server::ClientConnection

      def initialize
        @pending_client_messages = []
        @pending_server_messages = []
      end

      # ClientConnection interface methods
      def read_next_message
        Fiber.yield while @pending_client_messages.empty?

        @pending_client_messages.shift
      end

      def send_message(message)
        @pending_server_messages << message
      end

      # Test helper methods
      def <<(message)
        @pending_client_messages << message
      end

      def next_pending_server_message
        @pending_server_messages.shift
      end
    end

    def start_initialized_server(...)
      start_server(...)
      send_message a_valid_initialize_request
      send_message a_valid_initialized_notification
    end

    def start_server(...)
      prepare_server(...)

      @mock_client_connection = MockClientConnection.new
      @server_fiber = Fiber.new { @server.serve(@mock_client_connection) }
      @server_fiber.resume
    end

    def prepare_server(name: "test_server", version: nil)
      App.name(name) if name
      App.version(version) if version
      @server = Server.new(App.new)
    end

    def send_message(message)
      @mock_client_connection << message
      @server_fiber.resume
      next_pending_server_message
    end

    def next_pending_server_message
      result = @mock_client_connection.next_pending_server_message
      result = JSON.parse(result, symbolize_names: true) if result
      result
    end

    def a_valid_initialize_request
      json_rpc_message(
        method: Constants::RequestMethods::INITIALIZE,
        params: {
          protocolVersion: Constants::PROTOCOL_VERSION,
          capabilities: {},
          clientInfo: {
            name: "test_client",
            version: "1.0.0"
          }
        }
      )
    end

    def a_valid_initialized_notification
      json_rpc_notification(
        method: Constants::RequestMethods::INITIALIZED
      )
    end

    def a_valid_ping_request
      json_rpc_message(
        method: Constants::RequestMethods::PING
      )
    end

    def assert_successful_response(response)
      assert response[:result]
    end

    def assert_server_has_stopped
      refute_predicate @server_fiber, :alive?
    end

    def json_rpc_message(values)
      @next_id ||= 1

      result = {
        jsonrpc: Constants::JSON_RPC_VERSION,
        id: @next_id,
        **values
      }.to_json

      @next_id += 1

      result
    end

    def json_rpc_notification(values)
      {
        jsonrpc: Constants::JSON_RPC_VERSION,
        **values
      }.to_json
    end
  end
end
