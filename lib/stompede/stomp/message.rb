module Stompede
  module Stomp
    class Message
      # @return [String]
      attr_accessor :command

      # @return [Hash<String, String>]
      attr_accessor :headers

      # @return [String]
      attr_accessor :body

      def initialize
        @command = ""
        @headers = {}
        @body = ""
      end
    end
  end
end
