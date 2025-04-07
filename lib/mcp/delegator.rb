# frozen_string_literal: true

module MCP
  module Delegator
    def self.delegate(*methods)
      methods.each do |method_name|
        define_method(method_name) do |*args, **kwargs, &block|
          MCP::App.send(method_name, *args, **kwargs, &block)
        end
      end
    end

    delegate :name, :version, :resource, :resource_template, :tool
  end
end
