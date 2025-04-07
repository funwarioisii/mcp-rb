# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class ServerTest < MCPTest::TestCase
    def teardown
      App.reset!
    end

    def test_app_version
      App.version("1.2.3")
      app = App.new

      assert_equal "1.2.3", app.version
    end

    def test_app_name_and_version
      App.name("special_test_server")
      App.version("1.4.1")

      app = App.new

      assert_equal "special_test_server", app.name
      assert_equal "1.4.1", app.version
    end

    class MyApp < MCP::App
      name "sub_app"
      version "1.0.0"

      tool "neat_tool" do
        description "A tool that does something neat"
        argument :name, String, required: true
        call { |args| "Hello, #{args[:name]}!" }
      end
    end

    def test_inherited_app

      app = MyApp.new
      assert_equal "sub_app", app.name
      assert_equal "1.0.0", app.version
      assert_equal({content: [{type: "text", text: "Hello, world!"}], isError: false}, app.call_tool("neat_tool", name: "world"))
    end
  end
end
