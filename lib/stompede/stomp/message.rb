module Stompede
  module Stomp
    class Message
      HEADER_TRANSLATIONS = {
        '\\r' => "\r",
        '\\n' => "\n",
        '\\c' => ":",
        '\\\\' => '\\',
      }
      HEADER_TRANSLATIONS_KEYS = Regexp.union(HEADER_TRANSLATIONS.keys)

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
        # @see http://stomp.github.io/stomp-specification-1.2.html#Repeated_Header_Entries
        @headers[translate_header(key)] ||= translate_header(value)
      end

      private

      # @see http://stomp.github.io/stomp-specification-1.2.html#Value_Encoding
      def translate_header(value)
        value.gsub(HEADER_TRANSLATIONS_KEYS, HEADER_TRANSLATIONS)
      end
    end
  end
end
