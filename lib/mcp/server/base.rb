# frozen_string_literal: true

require "json"
require "English"
require "uri"
require_relative "../constants"
require_relative "client_connection"
require_relative "../app"

module MCP
  module Server
    # Base Server class for MCP implementation
    # Handles core protocol functionality independent of transport
    class Base
      attr_reader :name, :version, :app
      attr_accessor :tools, :resources, :resource_templates

      # @abstract
      # Represents a connection to a MCP client via a particular transport.
      # Each transport should implement a class implementing this interface.
      #
      # Connection setup and teardown should be handled outside of the server.
      # Once this object is passed to the server, it is expected to be ready to
      # read and write messages.
      module ClientConnection
        # Read the next message from the client.
        # This method should block until a message is available.
        # @return [String] The next message received (excluding the trailing newline)
        # @return [nil] if the connection was closed by the client
        def read_next_message
          raise NotImplementedError, "クライアント接続がread_next_messageを実装していません"
        end

        # Send a message to the client.
        # @param message [String] The message to send (without a trailing newline).
        def send_message(message)
          raise NotImplementedError, "クライアント接続がsend_messageを実装していません"
        end
      end

      def initialize(name:, version: "0.1.0")
        @name = name
        @version = version
        @app = App.new
        @tools = {}
        @resources = {}
        @resource_templates = {}
        @initialized = false
      end

      # standard:disable Lint/DuplicateMethods
      def name(value = nil)
        return @name if value.nil?

        @name = value
      end

      def version(value = nil)
        return @version if value.nil?

        @version = value
      end
      # standard:enable Lint/DuplicateMethods

      def tool(name, &block)
        @app.register_tool(name, &block)
      end

      def resource(name, &block)
        @app.register_resource(name, &block)
      end

      def resource_template(name, &block)
        @app.register_resource_template(name, &block)
      end

      def initialized?
        @initialized
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

      # [request] is a Ruby hash of JSON-RPC request
      # Each Server implementation should use this method in `.serve`
      def process_request(request)
        # initialization check
        # if not initialized or not initialize request, return error
        allowed_methods_before_initialized = [
          Constants::RequestMethods::INITIALIZE,
          Constants::RequestMethods::PING,
          Constants::RequestMethods::INITIALIZED,
          Constants::RequestMethods::NOTIFICATIONS_INITIALIZED
        ]

        case request[:method]
        when Constants::RequestMethods::INITIALIZE
          warn "call: handle initialize request"
          handle_initialize_request(request)
        when Constants::RequestMethods::PING
          handle_ping_request(request)
        when Constants::RequestMethods::INITIALIZED, Constants::RequestMethods::NOTIFICATIONS_INITIALIZED
          handle_initialized_notification(request)
        else
          unless initialized? || allowed_methods_before_initialized.include?(request[:method])
            return error_response(
              Constants::ErrorCodes::NOT_INITIALIZED,
              "Server not initialized",
              request[:id]
            )
          end

          handle_message(request)
        end
      rescue => e
        handle_error(e, request)
      end

      def handle_initialize_request(request)
        # Validate protocol version
        client_protocol_version = request.dig(:params, :protocolVersion)
        unless client_protocol_version == Constants::PROTOCOL_VERSION
          return error_response(
            Constants::ErrorCodes::INVALID_PARAMS,
            "Unsupported protocol version",
            request[:id]
          )
        end

        @initialized = true

        # Return server information and capabilities
        success_response(request[:id], {
          protocolVersion: Constants::PROTOCOL_VERSION,
          serverInfo: {
            name: @name,
            version: @version
          },
          capabilities: {
            tools: {
              listChanged: false
            },
            resources: {
              subscribe: false,
              listChanged: false
            }
          }
        })
      end

      def handle_ping_request(request)
        success_response(request[:id], true)
      end

      def handle_initialized_notification(request)
        @initialized = true
        nil
      end

      def handle_message(request)
        warn "handle_message: #{request.inspect}"
        case request[:method]
        when Constants::RequestMethods::TOOLS_LIST
          handle_list_tools(request)
        when Constants::RequestMethods::TOOLS_CALL
          handle_call_tool(request)
        when Constants::RequestMethods::RESOURCES_LIST
          handle_list_resources(request)
        when Constants::RequestMethods::RESOURCES_READ
          handle_read_resource(request)
        when Constants::RequestMethods::RESOURCES_TEMPLATES_LIST
          handle_list_resource_templates(request)
        else
          error_response(
            Constants::ErrorCodes::INVALID_REQUEST,
            "Unknown method: #{request[:method]}",
            request[:id]
          )
        end
      end

      def handle_list_tools(request)
        page_params = request.dig(:params, :page) || {}
        warn "list_tools: #{@app.list_tools.inspect}"
        success_response(request[:id], @app.list_tools(
          cursor: page_params[:offset]&.to_s,
          page_size: page_params[:limit]
        ))
      end

      def handle_call_tool(request)
        tool_id = request.dig(:params, :id) || request.dig(:params, :name)
        arguments = request.dig(:params, :arguments) || {}

        unless tool_id
          return error_response(
            Constants::ErrorCodes::INVALID_PARAMS,
            "Missing required parameter: id",
            request[:id]
          )
        end

        begin
          result = @app.call_tool(tool_id, **arguments)
          success_response(request[:id], result)
        rescue ArgumentError => e
          if e.message.include?("Tool not found")
            error_response(
              Constants::ErrorCodes::TOOL_NOT_FOUND,
              e.message,
              request[:id]
            )
          else
            error_response(
              Constants::ErrorCodes::TOOL_CALL_ERROR,
              e.message,
              request[:id]
            )
          end
        end
      end

      def handle_list_resources(request)
        page_params = request.dig(:params, :page) || {}
        success_response(request[:id], @app.list_resources(
          cursor: page_params[:offset]&.to_s,
          page_size: page_params[:limit]
        ))
      end

      def handle_list_resource_templates(request)
        page_params = request.dig(:params, :page) || {}
        success_response(request[:id], @app.list_resource_templates(
          cursor: page_params[:offset]&.to_s,
          page_size: page_params[:limit]
        ))
      end

      def handle_read_resource(request)
        uri = request.dig(:params, :uri)

        unless uri
          return error_response(
            Constants::ErrorCodes::INVALID_PARAMS,
            "Missing required parameter: uri",
            request[:id]
          )
        end

        begin
          result = @app.read_resource(uri)
          success_response(request[:id], result)
        rescue App::ResourceNotFoundError => e
          error_response(
            Constants::ErrorCodes::RESOURCE_NOT_FOUND,
            e.message,
            request[:id]
          )
        rescue App::ResourceReadError => e
          error_response(
            Constants::ErrorCodes::RESOURCE_READ_ERROR,
            e.message,
            request[:id]
          )
        end
      end

      def handle_error(e, request)
        error_response(
          Constants::ErrorCodes::INTERNAL_ERROR,
          "Internal error: #{e.message}",
          request[:id]
        )
      end

      def success_response(id, result)
        {
          jsonrpc: Constants::JSON_RPC_VERSION,
          id: id,
          result: result
        }
      end

      def error_response(code, message, id = nil, data = nil)
        response = {
          jsonrpc: Constants::JSON_RPC_VERSION,
          error: {
            code: code,
            message: message
          }
        }

        response[:id] = id if id
        response[:error][:data] = data if data

        response
      end

      # Start the server, blocking until the client disconnects
      # @abstract Subclass and implement this method to start the server using the
      # appropriate transport mechanism
      def serve
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end
    end
  end
end
