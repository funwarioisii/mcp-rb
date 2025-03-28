# frozen_string_literal: true

module MCP
  module Delegator
    BUILDER_METHODS = [:name, :version, :transport].freeze

    def self.delegate(*methods)
      methods.each do |method_name|
        define_method(method_name) do |*args, **kwargs, &block|
          if BUILDER_METHODS.include?(method_name)
            MCP.server_builder.send(method_name, args.first)
            MCP.server_build if MCP.server_buildable?
            return
          end

          MCP.server&.send(method_name, *args, **kwargs, &block)
        end
      end
    end

    delegate :name, :version, :resource, :resource_template, :tool,
      :transport, :port, :host # for HTTP server
  end
end
