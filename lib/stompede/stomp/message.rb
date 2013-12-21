module Stompede
  module Stomp
    class Message
      # @return [String]
      attr_reader :command

      # @return [Hash<String, String>]
      attr_reader :headers

      # @return [String]
      attr_reader :body

      def initialize
        @command = ""
        @headers = {}
        @body = ""
      end

      def write_command(command)
        @command = command
      end

      def write_header(key, value)
        @headers[key] = value
      end
    end
  end
end
