# frozen_string_literal: true

require "json"
require "open3"
require "securerandom"
require_relative "constants"

module MCP
  class Client
    attr_reader :command, :args, :process, :stdin, :stdout, :stderr, :wait_thread

    # @rbs (command: String, ?args: Array[untyped], ?name: String, ?version: String) -> void
    def initialize(command:, args: [], name: "mcp-client", version: VERSION)
      @command = command
      @args = args
      @process = nil
      @name = name
      @version = version
    end

    # @rbs () -> MCP::Client
    def connect
      return if @process

      start_server
      initialize_connection
      self
    end

    # @rbs () -> bool
    def running? = !@process.nil?

    # @rbs () -> Array[untyped]?
    def list_tools
      ensure_running
      send_request({
        jsonrpc: Constants::JSON_RPC_VERSION,
        method: Constants::RequestMethods::TOOLS_LIST,
        params: {},
        id: SecureRandom.uuid
      })
    end

    # @rbs (name: String, ?args: Hash[untyped, untyped]) -> Hash[untyped, untyped]?
    def call_tool(name:, args: {})
      ensure_running
      send_request({
        jsonrpc: Constants::JSON_RPC_VERSION,
        method: Constants::RequestMethods::TOOLS_CALL,
        params: {
          name: name,
          arguments: args
        },
        id: SecureRandom.uuid
      })
    end

    # @rbs () -> nil
    def close
      return unless @process

      @stdin.close
      @stdout.close
      @stderr.close
      Process.kill("TERM", @process)
      @wait_thread.join
      @process = nil
    rescue IOError, Errno::ESRCH
      # プロセスが既に終了している場合は無視
      @process = nil
    end

    private

    # @rbs () -> void
    def ensure_running
      raise "Server process not running. Call #start first." unless running?
    end

    # @rbs () -> void
    def initialize_connection
      response = send_request({
        jsonrpc: Constants::JSON_RPC_VERSION,
        method: "initialize",
        params: {
          protocolVersion: Constants::PROTOCOL_VERSION,
          client: {
            name: @name,
            version: @version
          }
        },
        id: SecureRandom.uuid
      })

      @stdin.puts(JSON.generate({
        jsonrpc: Constants::JSON_RPC_VERSION,
        method: "notifications/initialized"
      }))

      response
    end

    # @rbs () -> void
    def start_server
      @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(@command, *@args)
      @process = @wait_thread.pid

      Thread.new do
        while (line = @stderr.gets)
          warn "[MCP Server] #{line}"
        end
      rescue IOError
        # ignore when stream is closed
      end
    end

    # @rbs (Hash[untyped, untyped]) -> (Hash[untyped, untyped] | Array[untyped])
    def send_request(request)
      @stdin.puts(JSON.generate(request))
      response = @stdout.gets
      raise "No response from server" unless response

      result = JSON.parse(response, symbolize_names: true)
      if result[:error]
        raise "Server error: #{result[:error][:message]} (#{result[:error][:code]})"
      end

      result[:result]
    rescue JSON::ParserError => e
      raise "Invalid JSON response: #{e.message}"
    end
  end
end
