# frozen_string_literal: true

require "json"
require "English"
require "uri"
require_relative "constants"
require_relative "message_validator"
require_relative "server/client_connection"
require_relative "server/stdio_client_connection"

module MCP
  # A Server handles MCP requests from an MCP client using the App.
  class Server
    attr_reader :app

    def initialize(app)
      @app = app
      @initialized = false
      @message_validator = MessageValidator.new protocol_version: Constants::PROTOCOL_VERSION
    end

    def name
      @app.name
    end

    def version
      @app.version
    end

    def initialized?
      @initialized
    end

    # Serve a client via the given connection.
    # This method will block while the client is connected.
    # It's the caller's responsibility to create Threads or Fibers to handle multiple clients.
    # @param client_connection [ClientConnection] The connection to the client.
    def serve(client_connection)
      loop do
        next_message = client_connection.read_next_message
        break if next_message.nil? # Client closed the connection

        response = process_input(next_message)
        next unless response # Notifications don't return a response so don't send anything

        client_connection.send_message(response)
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
      result = begin
        request = JSON.parse(line)
        @message_validator.validate_client_message!(request)
        handle_request deep_symbolize_keys(request)
      rescue JSON::ParserError => e
        error_response(nil, Constants::ErrorCodes::PARSE_ERROR, "Invalid JSON: #{e.message}")
      rescue MessageValidator::UnknownMethod
        error_response(
          request["id"],
          Constants::ErrorCodes::METHOD_NOT_FOUND,
          "Unknown method: #{request["method"]}"
        )
      rescue MessageValidator::InvalidParams => e
        error_response(
          request["id"],
          Constants::ErrorCodes::INVALID_PARAMS,
          "Invalid params",
          {errors: e.errors}
        )
      rescue MessageValidator::InvalidMessage => e
        error_response(
          nil,
          Constants::ErrorCodes::INVALID_REQUEST,
          "Invalid request",
          {errors: e.errors}
        )
      rescue => e
        error_response(nil, Constants::ErrorCodes::INTERNAL_ERROR, e.message)
      end

      result = JSON.generate(result) if result
      result
    end

    def deep_symbolize_keys(obj)
      case obj
      when Hash
        obj.to_h { |key, value| [key.to_sym, deep_symbolize_keys(value)] }
      when Array
        obj.map { |value| deep_symbolize_keys(value) }
      else
        obj
      end
    end

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
      end
    end

    def handle_initialize(request)
      return error_response(request[:id], Constants::ErrorCodes::ALREADY_INITIALIZED, "Server already initialized") if @initialized

      client_version = request.dig(:params, :protocolVersion)
      unless Constants::SUPPORTED_PROTOCOL_VERSIONS.include?(client_version)
        return error_response(
          request[:id],
          Constants::ErrorCodes::INVALID_PARAMS,
          "Unsupported protocol version",
          {
            supported: Constants::SUPPORTED_PROTOCOL_VERSIONS,
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
            resources: {
              subscribe: false,
              listChanged: false
            },
            tools: {
              listChanged: false
            }
          },
          serverInfo: {
            name: @app.name,
            version: @app.version
          }
        }
      }
    end

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

    def handle_call_tool(request)
      name = request.dig(:params, :name)
      arguments = request.dig(:params, :arguments)
      begin
        result = @app.call_tool(name, **arguments.transform_keys(&:to_sym))
        if result[:isError]
          error_response(request[:id], Constants::ErrorCodes::INVALID_REQUEST, result[:content].first[:text])
        else
          success_response(request[:id], result)
        end
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

    def handle_ping(request)
      success_response(request[:id], {})
    end

    def success_response(id, result)
      {
        jsonrpc: MCP::Constants::JSON_RPC_VERSION,
        id: id,
        result: result
      }
    end

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
