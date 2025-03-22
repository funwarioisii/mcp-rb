require "io/wait"
require "minitest/snapshots"

require_relative "test_helper"

class SnapshotsTest < MCPTest::TestCase
  def test_hello_world_server_interaction
    with_started_server("examples/hello_world.rb") do |server_io|
      client_messages = [
        # Initialize request
        '{"jsonrpc": "2.0", "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test_client", "version": "1.0.0"}}, "id": 1}',
        # Initialized notification
        '{"jsonrpc": "2.0", "method": "notifications/initialized"}',
        # List tools request
        '{"jsonrpc": "2.0", "method": "tools/list", "id": 2}',
        # Call greet tool
        '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "greet", "arguments": {"name": "World"}}, "id": 3}',
        # List resources request
        '{"jsonrpc": "2.0", "method": "resources/list", "id": 4}',
        # Read resource request
        '{"jsonrpc": "2.0", "method": "resources/read", "params": {"uri": "hello://world"}, "id": 5}',
        # List resources templates request
        '{"jsonrpc": "2.0", "method": "resources/templates/list", "id": 6}',
        # Read resource template request
        '{"jsonrpc": "2.0", "method": "resources/read", "params": {"uri": "users://test"}, "id": 7 }',
        # Read nested resource template request
        '{"jsonrpc": "2.0", "method": "resources/read", "params": {"uri": "users://test/posts/3"}, "id": 9}'
      ]
      snapshot_text = record_interaction(server_io, client_messages)

      assert_matches_snapshot snapshot_text
    end
  end

  private

  def with_started_server(filename)
    root_path = File.expand_path("..", __dir__)
    server_path = File.join(root_path, filename)
    raise "Server file not found: #{filename}" unless File.exist?(server_path)

    IO.popen(["ruby", server_path], "r+") do |server_io|
      server_io.sync = true
      yield server_io
    end
  end

  def record_interaction(server_io, client_messages)
    snapshot = []
    client_messages.each do |msg|
      snapshot << "Client: #{msg}\n"
      server_io.puts msg
      server_io.wait_readable(0.5)

      while server_io.ready?
        response = server_io.gets(chomp: true)
        snapshot << "Server: #{response}\n"
      end
    end
    snapshot.join
  end
end
