# frozen_string_literal: true

module MCP
  module Server
    # @abstract
    # Represents a connection to a MCP client via a particular transport.
    # Each transport should implement a class implementing this interface.
    #
    # Connection setup and teardown should be handled outside of the server.
    # Once this object is passed to the server, it is expected to be ready to
    # read and write messages.
    module ClientConnection
      # Read the next message from the client.
      # This method should block until a message is available.
      # @return [String] The next message received (excluding the trailing newline)
      # @return [nil] if the connection was closed by the client
      def read_next_message
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end

      # Send a message to the client.
      # @param message [String] The message to send (without a trailing newline).
      def send_message(message)
        raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
      end
    end
  end
end
