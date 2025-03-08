# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"

module MCP
  class ClientTest < MCPTest::TestCase
    class MockServer
      attr_reader :input, :output, :error

      # @rbs () -> void
      def initialize
        reset_streams
      end

      # @rbs () -> bool
      def reset_streams
        @input = StringIO.new
        @output = StringIO.new
        @error = StringIO.new
        @responses = []
        @initialized = false
      end

      # @rbs (*String) -> Array[untyped]
      def start(*_args)
        reset_streams
        setup_init_response
        wait_thread = create_mock_thread

        [InputWrapper.new(@input, self), OutputWrapper.new(@output), @error, wait_thread]
      end

      # @rbs (Hash[untyped, untyped]) -> void
      def add_response(response)
        @responses << response
      end

      private

      # @rbs () -> void
      def setup_init_response
        @init_response = {
          jsonrpc: Constants::JSON_RPC_VERSION,
          result: {serverInfo: {name: "mock", version: "1.0.0"}},
          id: 1
        }
      end

      # @rbs () -> Thread
      def create_mock_thread
        thread = Thread.new {}
        def thread.pid
          12345
        end
        thread
      end

      # @rbs (String) -> Hash[untyped, untyped]?
      def handle_request(request)
        request_data = JSON.parse(request, symbolize_names: true)
        case request_data[:method]
        when MCP::Constants::RequestMethods::INITIALIZE
          @initialized = true
          @init_response
        when MCP::Constants::RequestMethods::INITIALIZED
          nil
        else
          return nil unless @initialized
          return nil unless request_data[:id]
          @responses.shift
        end
      end

      class InputWrapper < StringIO
        # @rbs (StringIO, MCP::ClientTest::MockServer) -> void
        def initialize(stringio, server)
          @stringio = stringio
          @server = server
        end

        # @rbs (String) -> void
        def puts(str)
          @stringio.puts(str)
          if (response = @server.send(:handle_request, str))
            @server.output.write(JSON.generate(response) + "\n")
            @server.output.rewind
          end
        end

        def method_missing(method, *args, &block)
          @stringio.send(method, *args, &block)
        end

        def respond_to_missing?(method, include_private = false)
          @stringio.respond_to?(method, include_private)
        end
      end

      class OutputWrapper < StringIO
        # @rbs (StringIO) -> void
        def initialize(stringio)
          @stringio = stringio
        end

        # @rbs () -> String
        def gets
          result = @stringio.gets
          @stringio.rewind
          result
        end

        def method_missing(method, *args, &block)
          @stringio.send(method, *args, &block)
        end

        def respond_to_missing?(method, include_private = false)
          @stringio.respond_to?(method, include_private)
        end
      end
    end

    # @rbs () -> MCP::Client
    def setup
      @mock_server = MockServer.new
      @client = Client.new(command: "mock")
      with_mock_server(@mock_server) do
        @client.connect
      end
    end

    # @rbs () -> nil
    def teardown
      @client.close if @client&.running?
    end

    # @rbs (MCP::ClientTest::MockServer) -> (MCP::Client | bool)
    def with_mock_server(mock_server)
      Open3.stub :popen3, mock_server.method(:start) do
        yield
      end
    end

    # @rbs () -> bool
    def test_initialize
      client = Client.new(command: "mock")
      assert_equal "mock", client.command
      assert_empty client.args
      refute client.running?
    end

    # @rbs () -> bool
    def test_initialize_with_args
      client = Client.new(command: "mock", args: ["--version"], name: "test-client", version: "1.0.0")
      assert_equal "mock", client.command
      assert_equal ["--version"], client.args
      refute client.running?
    end

    # @rbs () -> bool
    def test_connect
      assert @client.running?
      assert_equal 12345, @client.process
      assert @client.stdin
      assert @client.stdout
      assert @client.stderr
      assert @client.wait_thread
    end

    # @rbs () -> MatchData
    def test_list_tools_without_connection
      client = Client.new(command: "mock")
      error = assert_raises(RuntimeError) { client.list_tools }
      assert_match(/Server process not running/, error.message)
    end

    # @rbs () -> MatchData
    def test_call_tool_without_connection
      client = Client.new(command: "mock")
      error = assert_raises(RuntimeError) { client.call_tool(name: "test") }
      assert_match(/Server process not running/, error.message)
    end

    # @rbs () -> bool
    def test_close_without_connection
      client = Client.new(command: "mock")
      client.close
      refute client.running?
    end

    # @rbs () -> bool
    def test_list_tools
      mock_server = MockServer.new
      client = Client.new(command: "mock")

      with_mock_server(mock_server) do
        client.connect
        mock_server.add_response({
          jsonrpc: Constants::JSON_RPC_VERSION,
          result: [{name: "test_tool", description: "Test tool"}],
          id: 2
        })

        result = client.list_tools
        assert_equal [{name: "test_tool", description: "Test tool"}], result
      end
    end

    # @rbs () -> bool
    def test_call_tool
      mock_server = MockServer.new
      client = Client.new(command: "mock")

      with_mock_server(mock_server) do
        client.connect
        mock_server.add_response({
          jsonrpc: Constants::JSON_RPC_VERSION,
          result: {success: true},
          id: 2
        })

        result = client.call_tool(name: "test_tool", args: {key: "value"})
        assert_equal({success: true}, result)
      end
    end
  end
end
