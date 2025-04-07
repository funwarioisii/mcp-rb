# frozen_string_literal: true

require "English"
require "json"

require_relative "mcp/version"
require_relative "mcp/constants"
require_relative "mcp/autorun"
require_relative "mcp/app"
require_relative "mcp/server"
require_relative "mcp/delegator"
require_relative "mcp/client"

module MCP
  extend MCP::Autorun
  @app_file = cleaned_caller(1).flatten.first
  class << self
    def server
      @server ||= Server.new(App.new)
    end

    def run?
      File.expand_path($PROGRAM_NAME) == File.expand_path(@app_file) && $ERROR_INFO.nil? && $stdin.stat.readable?
    end
  end

  # require 'mcp' したファイルで最後に到達したら実行されるようにするため
  # https://docs.ruby-lang.org/ja/latest/method/Kernel/m/at_exit.html
  at_exit { server.serve(Server::StdioClientConnection.new) if run? && $ERROR_INFO.nil? && server }

  def self.new(**options, &block)
    @server = Server.new(**options)
    return @server if block.nil?

    if block.arity.zero?
      @server.instance_eval(&block)
    else
      (block.arity == 1) ? yield(@server) : yield
    end

    @server
  end
end

extend MCP::Delegator # standard:disable Style/MixinUsage
