# frozen_string_literal: true

require "English"
require "json"

require_relative "mcp/version"
require_relative "mcp/constants"
require_relative "mcp/app"
require_relative "mcp/server"
require_relative "mcp/client"
require_relative "mcp/dsl"

module MCP
end

extend MCP::DSL # standard:disable Style/MixinUsage

was_required_by_app_file = caller_locations(1..1).first.absolute_path == File.absolute_path($PROGRAM_NAME)

at_exit do
  if $ERROR_INFO.nil? && was_required_by_app_file
    server = MCP::DSL.build_server(self)
    server.serve(MCP::Server::StdioClientConnection.new)
  end
end
