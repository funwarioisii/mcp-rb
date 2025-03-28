# frozen_string_literal: true

module MCP
  module Constants
    JSON_RPC_VERSION = "2.0"
    PROTOCOL_VERSION = "2024-11-05"

    # JSON-RPC request methods
    module RequestMethods
      INITIALIZE = "initialize"
      INITIALIZED = "initialized"
      NOTIFICATIONS_INITIALIZED = "notifications/initialized"
      PING = "ping"
      TOOLS_LIST = "tools/list"
      TOOLS_CALL = "tools/call"
      RESOURCES_LIST = "resources/list"
      RESOURCES_READ = "resources/read"
      RESOURCES_TEMPLATES_LIST = "resources/templates/list"
    end

    # JSON-RPC error codes
    module ErrorCodes
      # Standard JSON-RPC error codes
      PARSE_ERROR = -32700
      INVALID_REQUEST = -32600
      METHOD_NOT_FOUND = -32601
      INVALID_PARAMS = -32602
      INTERNAL_ERROR = -32603

      # MCP-specific error codes
      NOT_INITIALIZED = -32002
      ALREADY_INITIALIZED = -32003
      TOOL_NOT_FOUND = -32010
      TOOL_CALL_ERROR = -32011
      RESOURCE_NOT_FOUND = -32020
      RESOURCE_READ_ERROR = -32021
    end
  end
end.freeze
