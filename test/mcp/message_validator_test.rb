# frozen_string_literal: true

require_relative "../test_helper"

module MCP
  class MessageValidatorTest < MCPTest::TestCase
    def test_invalid_message
      validator = MessageValidator.new

      invalid_message = valid_mcp_message.except("jsonrpc")

      assert_raises(MessageValidator::InvalidMessage) do
        validator.validate_client_message!(invalid_message)
      end
    end

    def test_unknown_method
      validator = MessageValidator.new

      message_with_unknown_method = valid_mcp_message.merge("method" => "invalidMethod")

      assert_raises(MessageValidator::UnknownMethod) do
        validator.validate_client_message!(message_with_unknown_method)
      end
    end

    def test_invalid_params
      validator = MessageValidator.new

      message_with_invalid_params = valid_mcp_message.merge("params" => {"invalid_param" => "value"})

      assert_raises(MessageValidator::InvalidParams) do
        validator.validate_client_message!(message_with_invalid_params)
      end
    end

    private

    def valid_mcp_message
      {
        "jsonrpc" => "2.0",
        "method" => "resources/read",
        "params" => {"uri" => "hello://world"},
        "id" => 1
      }
    end
  end
end
