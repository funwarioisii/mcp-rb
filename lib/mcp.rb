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
  @autorun = MCP::Autorun.app_file? caller 

  class << self
    attr_reader :server

    def initialize_server(name:, **options)
      @server ||= Server.new(name: name, **options)
    end

    def autorun?
      @autorun && $ERROR_INFO.nil? && $stdin.stat.readable?
    end
  end

  # require 'mcp' したファイルで最後に到達したら実行されるようにするため
  # https://docs.ruby-lang.org/ja/latest/method/Kernel/m/at_exit.html
  at_exit { server.serve(Server::StdioClientConnection.new) if autorun? }

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
