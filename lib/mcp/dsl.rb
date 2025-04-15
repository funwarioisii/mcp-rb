# frozen_string_literal: true

require "forwardable"

require_relative "dsl/server_builder"

module MCP
  module DSL
    def self.extended(base)
      base.instance_variable_set(:@server_builder, ServerBuilder.new)
      base.extend SingleForwardable
      base.def_delegators :@server_builder, :name, :version, :resource, :resource_template, :tool
    end

    def self.build_server(mod)
      server_builder = mod.instance_variable_get(:@server_builder)
      server_builder.build
    end
  end
end
