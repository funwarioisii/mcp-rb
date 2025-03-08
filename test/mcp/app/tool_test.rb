# frozen_string_literal: true

require_relative "../../test_helper"

module MCP
  class App
    class ToolTest < MCPTest::TestCase
      # @rbs () -> MCP::App
      def setup
        @app = App.new
      end

      # @rbs () -> bool
      def test_tools_pagination
        10.times do |i|
          @app.register_tool("tool#{i}") do
            description "Tool #{i}"
            argument :value, String, required: true, description: "Value for tool #{i}"

            call do |args|
              "Tool #{i}: #{args[:value]}"
            end
          end
        end

        # First page
        result = @app.list_tools(page_size: 5)
        assert_equal 5, result[:tools].length
        assert_equal "tool0", result[:tools].first[:name]
        assert_equal "tool4", result[:tools].last[:name]

        # Second page
        result = @app.list_tools(page_size: 5, cursor: "5")
        assert_equal 5, result[:tools].length
        assert_equal "tool5", result[:tools].first[:name]
        assert_equal "tool9", result[:tools].last[:name]
      end

      # @rbs () -> bool
      def test_register_tool
        tool = @app.register_tool("greet") do
          description "Greet someone by name"
          argument :name, String, required: true, description: "Name to greet"

          call do |args|
            "Hello, #{args[:name]}!"
          end
        end

        assert_equal "greet", tool[:name]
        assert_equal "Greet someone by name", tool[:description]
        assert_equal(
          {
            type: :object,
            properties: {
              name: {
                type: :string,
                description: "Name to greet"
              }
            },
            required: [:name]
          },
          tool[:input_schema]
        )

        result = @app.call_tool("greet", name: "World")
        assert_equal({
          content: [{type: "text", text: "Hello, World!"}],
          isError: false
        }, result)
      end

      # @rbs () -> bool
      def test_register_tool_with_multiple_arguments
        tool = @app.register_tool("format_greeting") do
          description "Format a greeting with title and name"
          argument :title, String, required: true, description: "Title (Mr./Ms./Dr. etc.)"
          argument :first_name, String, required: true, description: "First name"
          argument :last_name, String, required: true, description: "Last name"
          argument :suffix, String, required: false, description: "Name suffix (Jr./Sr./III etc.)"

          call do |args|
            name_parts = [args[:first_name], args[:last_name]]
            name_parts << args[:suffix] if args[:suffix]
            "#{args[:title]} #{name_parts.join(" ")}"
          end
        end

        # Test schema
        assert_equal "format_greeting", tool[:name]
        assert_equal "Format a greeting with title and name", tool[:description]
        assert_equal(
          {
            type: :object,
            properties: {
              title: {
                type: :string,
                description: "Title (Mr./Ms./Dr. etc.)"
              },
              first_name: {
                type: :string,
                description: "First name"
              },
              last_name: {
                type: :string,
                description: "Last name"
              },
              suffix: {
                type: :string,
                description: "Name suffix (Jr./Sr./III etc.)"
              }
            },
            required: [:title, :first_name, :last_name]
          },
          tool[:input_schema]
        )

        # Test with required arguments only
        result = @app.call_tool("format_greeting",
          title: "Dr.",
          first_name: "John",
          last_name: "Smith")
        assert_equal({
          content: [{type: "text", text: "Dr. John Smith"}],
          isError: false
        }, result)

        # Test with optional argument
        result = @app.call_tool("format_greeting",
          title: "Mr.",
          first_name: "John",
          last_name: "Smith",
          suffix: "Jr.")
        assert_equal({
          content: [{type: "text", text: "Mr. John Smith Jr."}],
          isError: false
        }, result)

        # Test with missing required argument
        result = @app.call_tool("format_greeting",
          first_name: "John",
          last_name: "Smith")
        assert result[:isError]
        assert_equal "Error: Missing required param :title", result.dig(:content, 0, :text)
      end

      # @rbs () -> MatchData
      def test_tool_without_handler
        error = assert_raises(ArgumentError) do
          @app.register_tool("invalid") do
            description "Invalid tool without handler"
          end
        end
        assert_match(/Handler must be provided/, error.message)
      end

      # @rbs () -> MatchData
      def test_tool_with_invalid_name
        error = assert_raises(ArgumentError) do
          @app.register_tool(nil) do
            description "Invalid tool"
            call do |args|
              "test"
            end
          end
        end
        assert_match(/Tool name cannot be nil or empty/, error.message)
      end

      # @rbs () -> bool
      def test_tool_with_nested_object
        tool = @app.register_tool("create_user") do
          description "Create a user with details"
          argument :user, required: true do
            argument :username, String, required: true, description: "Username"
            argument :email, String, required: true, description: "Email address"
            argument :age, Integer, required: false, description: "Age"
          end

          call do |args|
            user = args[:user]
            age = user[:age] || "N/A"
            "User created: #{user[:username]}, #{user[:email]}, #{age}"
          end
        end

        # Test schema
        assert_equal "create_user", tool[:name]
        assert_equal "Create a user with details", tool[:description]
        assert_equal(
          {
            type: :object,
            properties: {
              user: {
                type: :object,
                properties: {
                  username: {type: :string, description: "Username"},
                  email: {type: :string, description: "Email address"},
                  age: {type: :integer, description: "Age"}
                },
                required: [:username, :email],
                description: ""
              }
            },
            required: [:user]
          },
          tool[:input_schema]
        )

        # Test with complete data
        result = @app.call_tool("create_user", user: {username: "john", email: "john@example.com", age: 30})
        assert_equal({
          content: [{type: "text", text: "User created: john, john@example.com, 30"}],
          isError: false
        }, result)

        # Test with only required fields
        result = @app.call_tool("create_user", user: {username: "jane", email: "jane@example.com"})
        assert_equal({
          content: [{type: "text", text: "User created: jane, jane@example.com, N/A"}],
          isError: false
        }, result)

        # Test without :user argument
        result = @app.call_tool("create_user")
        assert result[:isError]
        assert_equal "Error: Missing required param :user", result.dig(:content, 0, :text)

        # Test with :user missing required field
        result = @app.call_tool("create_user", user: {email: "john@example.com"})
        assert result[:isError]
        assert_equal "Error: Missing required param user.username", result.dig(:content, 0, :text)
      end

      # Test for a tool with an array of simple types
      # @rbs () -> bool
      def test_tool_with_array_argument
        @app.register_tool("sum_numbers") do
          description "Sum an array of numbers"
          argument :numbers, Array, items: Integer, description: "Array of numbers to sum"

          call do |args|
            args[:numbers].sum.to_s
          end
        end

        # Test schema
        result = @app.list_tools
        assert_equal 1, result[:tools].size
        assert_equal({
          name: "sum_numbers",
          description: "Sum an array of numbers",
          inputSchema: {
            type: :object,
            properties: {
              numbers: {
                type: :array,
                description: "Array of numbers to sum",
                items: {type: :integer}
              }
            },
            required: []
          }
        }, result[:tools].first)

        # Test with array of integers
        result = @app.call_tool("sum_numbers", numbers: [1, 2, 3])
        assert_equal({
          content: [{type: "text", text: "6"}],
          isError: false
        }, result)

        # Test with empty array
        result = @app.call_tool("sum_numbers", numbers: [])
        assert_equal({
          content: [{type: "text", text: "0"}],
          isError: false
        }, result)

        # Test with non-integer values
        result = @app.call_tool("sum_numbers", numbers: [1, "two", 3])
        assert result[:isError]
        assert_equal "Error: Expected integer for numbers[1], got String", result.dig(:content, 0, :text)
      end

      # Test for a tool with an array of objects
      # @rbs () -> bool
      def test_tool_with_array_of_objects
        @app.register_tool("list_users") do
          description "List users with their details"
          argument :users, Array do
            argument :name, String, required: true, description: "User's name"
            argument :age, Integer, required: true, description: "User's age"
          end

          call do |args|
            users = args[:users]
            users.each do |user|
              raise "Missing name" unless user[:name]
              raise "Missing age" unless user[:age]
            end
            users.map { |u| "#{u[:name]} (#{u[:age]})" }.join(", ")
          end
        end

        # Test schema
        result = @app.list_tools
        assert_equal 1, result[:tools].size
        assert_equal({
          name: "list_users",
          description: "List users with their details",
          inputSchema: {
            type: :object,
            properties: {
              users: {
                type: :array,
                description: "",
                items: {
                  type: :object,
                  properties: {
                    name: {type: :string, description: "User's name"},
                    age: {type: :integer, description: "User's age"}
                  },
                  required: [:name, :age]
                }
              }
            },
            required: []
          }
        }, result[:tools].first)

        # Test with array of complete objects
        result = @app.call_tool("list_users", users: [{name: "Alice", age: 30}, {name: "Bob", age: 25}])
        assert_equal({
          content: [{type: "text", text: "Alice (30), Bob (25)"}],
          isError: false
        }, result)

        # Test with empty array
        result = @app.call_tool("list_users", users: [])
        assert_equal({
          content: [{type: "text", text: ""}],
          isError: false
        }, result)

        # Test with array where an object misses a required field
        result = @app.call_tool("list_users", users: [{name: "Alice"}, {name: "Bob", age: 25}])
        assert result[:isError]
        assert_equal "Error: Missing required param users[0].age", result.dig(:content, 0, :text)
      end
    end
  end
end
