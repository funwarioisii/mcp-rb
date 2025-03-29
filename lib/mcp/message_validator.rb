# frozen_string_literal: true

require "json_schemer"

module MCP
  class MessageValidator
    SCHEMA_ROOT_PATH = File.expand_path(File.join("..", "..", "schemas"), __dir__)

    # Initializes a new validator for messages according to the specified protocol version
    #
    # @param protocol_version [String] The version of the protocol to validate against, defaults to the current version
    #   defined in Constants::PROTOCOL_VERSION
    # @return [MessageValidator] A new instance of MessageValidator
    def initialize(protocol_version: Constants::PROTOCOL_VERSION)
      schema_path = File.join(SCHEMA_ROOT_PATH, "#{protocol_version}.json")
      @root_schema = JSONSchemer.schema(Pathname.new(schema_path))
    end

    # Validates a client message against the JSON schema
    #
    # Raises an exception if the message doesn't conform to the schema otherwise does nothing.
    #
    # @param message [Hash] The client message to validate - should be a JSON object with string keys
    # @raise [InvalidMessage] If the message isn't a valid JSON-RPC message
    # @raise [InvalidMethod] If the method in the message is invalid
    # @raise [InvalidParams] If the parameters in the message are invalid
    def validate_client_message!(message)
      ensure_minimal_client_message_requirements!(message)

      all_errors = client_message_validation_errors(message)
      return if all_errors.empty?

      params_errors = params_errors_of_matching_sub_schema(message, all_errors)
      raise UnknownMethod if params_errors.empty?
      raise InvalidParams.new(params_errors)
    end

    # Exception raised when the message is not a valid JSON-RPC message
    #
    # @attr_reader errors [Array<String>] The validation error messages
    class InvalidMessage < StandardError
      attr_reader :errors

      def initialize(errors)
        super(errors.map { _1["error"] }.join(", "))
        @errors = errors.map { _1["error"] }
      end
    end

    # Exception raised when the method of the message is unknown
    class UnknownMethod < StandardError; end

    # Exception raised when parameters in the message are invalid
    #
    # @attr_reader errors [Array<String>] The validation error messages
    class InvalidParams < InvalidMessage; end

    private

    def ensure_minimal_client_message_requirements!(message)
      # Validate against notification since it's the minimum requirement for a valid JSON-RPC message
      errors = validation_errors(message, "JSONRPCNotification")
      raise InvalidMessage.new(errors) if errors.any?
    end

    def client_message_validation_errors(message)
      if message.key? "id"
        validation_errors(message, "ClientRequest")
      else
        validation_errors(message, "ClientNotification")
      end
    end

    def params_errors_of_matching_sub_schema(message, all_errors)
      # JSON Schemer returns errors for all sub-schemas if none of them match the data.
      # So first we group the errors by the sub-schema they were produced by.
      errors_grouped_by_sub_schema = all_errors.group_by { |error|
        # /definitions/SubSchemaName/...
        _, _, sub_schema, = error["schema_pointer"].split("/")
        sub_schema
      }

      errors_grouped_by_sub_schema.each do |sub_schema_name, errors|
        # If there is an error for the "method" property, we know that this is not the correct sub-schema.
        next if errors.any? { _1["data_pointer"] == "/method" }

        # The remaining errors are for params etc. which is what we want
        return errors
      end

      []
    end

    def matching_sub_schema?(json, sub_schema_name)
      sub_schema = sub_schema(sub_schema_name)
      sub_schema.valid?(json)
    end

    def validation_errors(json, sub_schema_name)
      sub_schema = sub_schema(sub_schema_name)
      sub_schema.validate(json).to_a.map { _1.except("schema", "root_schema") }
    end

    def sub_schema(name)
      @root_schema.ref("#/definitions/#{name}")
    end
  end
end
