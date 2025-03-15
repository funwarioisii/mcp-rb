# MCP-RB

A lightweight Ruby framework for implementing MCP (Model Context Protocol) servers with a Sinatra-like DSL.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mcp-rb'
```

## Usage

Here's a simple example of how to create an MCP server:

```ruby
require 'mcp'

name "hello-world"

version "1.0.0"

# Define a resource
resource "hello://world" do
  name "Hello World"
  description "A simple hello world message"
  call { "Hello, World!" }
end

# Define a resource template
resource_template "hello://{user_name}" do
  name "Hello User"
  description "A simple hello user message"
  call { |args| "Hello, #{args[:user_name]}!" }
end

# Define a tool
tool "greet" do
  description "Greet someone by name"
  argument :name, String, required: true, description: "Name to greet"
  call do |args|
    "Hello, #{args[:name]}!"
  end
end

# Define a tool with nested arguments
tool "greet_full_name" do
  description "Greet someone by their full name"
  argument :person, required: true, description: "Person to greet" do
    argument :first_name, String, required: false, description: "First name"
    argument :last_name, String, required: false, description: "Last name"
  end
  call do |args|
    "Hello, First: #{args[:person][:first_name]} Last: #{args[:person][:last_name]}!"
  end
end

# Define a tool with an Array argument
tool "group_greeting" do
  description "Greet multiple people at once"
  argument :people, Array, required: true, items: String, description: "People to greet"
  call do |args|
    args[:people].map { |person| "Hello, #{person}!" }.join(", ")
  end
end
```

## Supported specifications

Reference: [MCP 2024-11-05](https://spec.modelcontextprotocol.io/specification/2024-11-05/)

- [Base Protocol](https://spec.modelcontextprotocol.io/specification/2024-11-05/basic/)
  - ping
  - stdio transport
- [Server features](https://spec.modelcontextprotocol.io/specification/2024-11-05/server/)
  - Resources
    - resources/read
    - resources/list
    - resources/templates/list
  - Tools
    - tools/list
    - tools/call

Any capabilities are not supported yet.

## Testing

```bash
ruby -Ilib:test -e "Dir.glob('./test/**/*_test.rb').each { |f| require f }"
```

Test with MCP Inspector

```bash
bunx @modelcontextprotocol/inspector $(pwd)/examples/hello_world.rb
```

## Formatting

```bash
bundle exec standardrb --fix
```

## Release

To release a new version:

1. Update version in `lib/mcp/version.rb`
2. Update `CHANGELOG.md`
3. Create a git tag

```bash
git add .
git commit -m "Release vx.y.z"
git tag vx.y.z
git push --tags
```

1. Build and push to RubyGems

```bash
gem build mcp-rb.gemspec
gem push mcp-rb-*.gem
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md)
