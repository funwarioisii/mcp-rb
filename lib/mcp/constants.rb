# frozen_string_literal: true

module MCP
  module Constants
    JSON_RPC_VERSION = "2.0"
    SUPPORTED_PROTOCOL_VERSIONS = %w[2024-11-05].freeze
    PROTOCOL_VERSION = SUPPORTED_PROTOCOL_VERSIONS.max

    module ErrorCodes
      NOT_INITIALIZED = -32_002
      ALREADY_INITIALIZED = -32_002

      PARSE_ERROR = -32_700
      INVALID_REQUEST = -32_600
      METHOD_NOT_FOUND = -32_601
      INVALID_PARAMS = -32_602
      INTERNAL_ERROR = -32_603
    end

    module RequestMethods
      INITIALIZE = "initialize"
      INITIALIZED = "notifications/initialized"
      PING = "ping"
      TOOLS_LIST = "tools/list"
      TOOLS_CALL = "tools/call"
      RESOURCES_LIST = "resources/list"
      RESOURCES_READ = "resources/read"
      RESOURCES_TEMPLATES_LIST = "resources/templates/list"
    end
  end
end.freeze
