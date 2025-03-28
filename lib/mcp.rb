# frozen_string_literal: true

require_relative "mcp/version"
require_relative "mcp/constants"
require_relative "mcp/app"
require_relative "mcp/server"
require_relative "mcp/delegator"
require_relative "mcp/client"

module MCP
  class << self
    attr_reader :server

    def server_builder
      @server_builder ||= ServerBuilder.new
    end

    def server_buildable?
      server_builder.buildable?
    end

    def server_build
      @server = server_builder.build
    end
  end

  # ServerBuilder is a builder class for MCP::Server
  # when all of :transport, :name, :version are filled, call build method
  class ServerBuilder
    attr_reader :server

    def initialize
      @server = nil
    end

    def transport(transport)
      @transport = transport

      if buildable?
        MCP.server_build
      else
        self
      end
    end

    def name(name)
      @name = name

      if buildable?
        MCP.server_build
      else
        self
      end
    end

    def version(version)
      @version = version

      if buildable?
        MCP.server_build
      else
        self
      end
    end

    def build
      raise "Name is not set" if @name.nil?
      raise "Version is not set" if @version.nil?

      @server = case @transport
      when :stdio
        Server::StdioServer.new(name: @name, version: @version)
      when :http
        Server::FalconHttpServer.new(name: @name, version: @version)
      else
        Server::StdioServer.new(name: @name, version: @version)
      end

      @server
    end

    def buildable?
      return false if @name.nil?
      return false if @version.nil?
      return false if builded?

      true
    end

    def builded?
      !@server.nil?
    end
  end

  # require 'mcp' したファイルで最後に到達したら実行されるようにするため
  # https://docs.ruby-lang.org/ja/latest/method/Kernel/m/at_exit.html
  at_exit { server.serve if $ERROR_INFO.nil? && server }
end

extend MCP::Delegator # standard:disable Style/MixinUsage
