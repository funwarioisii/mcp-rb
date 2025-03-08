# frozen_string_literal: true

require "json"
require "English"
require "uri"
require_relative "constants"

module MCP
  class Server
    attr_writer :name, :version
    attr_reader :initialized

    # @rbs (name: String, ?version: String) -> void
    def initialize(name:, version: "0.1.0")
      @name = name
      @version = version
      @app = App.new
      @initialized = false
      @supported_protocol_versions = [Constants::PROTOCOL_VERSION]
    end

    # @rbs (?nil) -> String
    def name(value = nil)
      return @name if value.nil?

      @name = value
    end

    # @rbs (?String?) -> String
    def version(value = nil)
      return @version if value.nil?

      @version = value
      @supported_protocol_versions << value
    end

    # @rbs (String?) -> Hash[untyped, untyped]?
    def tool(name, &block)
      @app.register_tool(name, &block)
    end

    # @rbs (String?) -> Hash[untyped, untyped]?
    def resource(uri, &block)
      @app.register_resource(uri, &block)
    end

    # @rbs (String?) -> Hash[untyped, untyped]?
    def resource_template(uri_template, &block)
      @app.register_resource_template(uri_template, &block)
    end

    def run
      while (input = $stdin.gets)
        process_input(input)
      end
    end

    def list_tools
      @app.list_tools[:tools]
    end

    def call_tool(name, **args)
      @app.call_tool(name, **args).dig(:content, 0, :text)
    end

    def list_resources
      @app.list_resources[:resources]
    end

    def list_resource_templates
      @app.list_resource_templates[:resourceTemplates]
    end

    def read_resource(uri)
      @app.read_resource(uri).dig(:contents, 0, :text)
    end

    private

    def process_input(line)
      request = JSON.parse(line, symbolize_names: true)
      response = handle_request(request)
      return unless response # 通知の場合はnilが返されるので、何も出力しない

      response_json = JSON.generate(response)
      $stdout.puts(response_json)
      $stdout.flush
    rescue JSON::ParserError => e
      error_response(nil, Constants::ErrorCodes::INVALID_REQUEST, "Invalid JSON: #{e.message}")
    rescue => e
      error_response(nil, Constants::ErrorCodes::INTERNAL_ERROR, e.message)
    end

    # @rbs (Hash[untyped, untyped]) -> Hash[untyped, untyped]?
    def handle_request(request)
      allowed_methods = [
        Constants::RequestMethods::INITIALIZE,
        Constants::RequestMethods::INITIALIZED,
        Constants::RequestMethods::PING
      ]
      if !@initialized && !allowed_methods.include?(request[:method])
        return error_response(request[:id], Constants::ErrorCodes::NOT_INITIALIZED, "Server not initialized")
      end

      case request[:method]
      when Constants::RequestMethods::INITIALIZE then handle_initialize(request)
      when Constants::RequestMethods::INITIALIZED then handle_initialized(request)
      when Constants::RequestMethods::PING then handle_ping(request)
      when Constants::RequestMethods::TOOLS_LIST then handle_list_tools(request)
      when Constants::RequestMethods::TOOLS_CALL then handle_call_tool(request)
      when Constants::RequestMethods::RESOURCES_LIST then handle_list_resources(request)
      when Constants::RequestMethods::RESOURCES_READ then handle_read_resource(request)
      when Constants::RequestMethods::RESOURCES_TEMPLATES_LIST then handle_list_resources_templates(request)
      else
        error_response(request[:id], Constants::ErrorCodes::METHOD_NOT_FOUND, "Unknown method: #{request[:method]}")
      end
    end

    # @rbs (Hash[untyped, untyped]) -> Hash[untyped, untyped]
    def handle_initialize(request)
      return error_response(request[:id], Constants::ErrorCodes::ALREADY_INITIALIZED, "Server already initialized") if @initialized

      client_version = request.dig(:params, :protocolVersion)
      unless @supported_protocol_versions.include?(client_version)
        return error_response(
          request[:id],
          Constants::ErrorCodes::UNSUPPORTED_PROTOCOL_VERSION,
          "Unsupported protocol version",
          {
            supported: @supported_protocol_versions,
            requested: client_version
          }
        )
      end

      {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: request[:id],
        result: {
          protocolVersion: Constants::PROTOCOL_VERSION,
          capabilities: {
            logging: {},
            prompts: {
              listChanged: false
            },
            resources: {
              subscribe: false,
              listChanged: false
            },
            tools: {
              listChanged: false
            }
          },
          serverInfo: {
            name: @name,
            version: @version
          }
        }
      }
    end

    # @rbs (Hash[untyped, untyped]) -> nil
    def handle_initialized(request)
      return error_response(request[:id], Constants::ErrorCodes::ALREADY_INITIALIZED, "Server already initialized") if @initialized

      @initialized = true
      nil  # 通知に対しては応答を返さない
    end

    def handle_list_tools(request)
      cursor = request.dig(:params, :cursor)
      result = @app.list_tools(cursor: cursor)
      success_response(request[:id], result)
    end

    # @rbs (Hash[untyped, untyped]) -> Hash[untyped, untyped]
    def handle_call_tool(request)
      name = request.dig(:params, :name)
      arguments = request.dig(:params, :arguments)
      begin
        result = @app.call_tool(name, **arguments.transform_keys(&:to_sym))
        success_response(request[:id], result)
      rescue ArgumentError => e
        error_response(request[:id], Constants::ErrorCodes::INVALID_REQUEST, e.message)
      end
    end

    def handle_list_resources(request)
      cursor = request.dig(:params, :cursor)
      result = @app.list_resources(cursor:)
      success_response(request[:id], result)
    end

    def handle_list_resources_templates(request)
      cursor = request.dig(:params, :cursor)
      result = @app.list_resource_templates(cursor:)
      success_response(request[:id], result)
    end

    def handle_read_resource(request)
      uri = request.dig(:params, :uri)
      result = @app.read_resource(uri)

      if result
        success_response(request[:id], result)
      else
        error_response(request[:id], Constants::ErrorCodes::INVALID_REQUEST, "Resource not found", {uri: uri})
      end
    end

    # @rbs (Hash[untyped, untyped]) -> Hash[untyped, untyped]
    def handle_ping(request)
      success_response(request[:id], {})
    end

    # @rbs (Integer, Hash[untyped, untyped]) -> Hash[untyped, untyped]
    def success_response(id, result)
      {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: id,
        result: result
      }
    end

    # @rbs (Integer, Integer, String, ?Hash[untyped, untyped]?) -> Hash[untyped, untyped]
    def error_response(id, code, message, data = nil)
      response = {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: id,
        error: {
          code: code,
          message: message
        }
      }
      response[:error][:data] = data if data
      response
    end
  end
end
