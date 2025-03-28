require_relative "lib/mcp/version"

Gem::Specification.new do |spec|
  spec.name = "mcp-rb"
  spec.version = MCP::VERSION
  spec.authors = ["funwarioisii"]
  spec.email = ["kazuyukihashimoto2006@gmail.com"]

  spec.summary = "A lightweight Ruby framework for implementing MCP (Model Context Protocol) servers"
  spec.description = "MCP-RB is a Ruby framework that provides a Sinatra-like DSL for implementing Model Context Protocol servers."
  spec.homepage = "https://github.com/funwarioisii/mcp-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
    lib/**/*
    README.md
    LICENSE.txt
    CHANGELOG.md
  ])
  spec.require_paths = ["lib"]

  spec.add_dependency "addressable", "~> 2.8.0"
end
