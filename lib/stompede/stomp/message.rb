module Stompede
  module Stomp
    class Message
      HEADER_TRANSLATIONS = {
        '\\r' => "\r",
        '\\n' => "\n",
        '\\c' => ":",
        '\\\\' => '\\',
      }.freeze
      HEADER_TRANSLATIONS_KEYS = Regexp.union(HEADER_TRANSLATIONS.keys).freeze
      HEADER_REVERSE_TRANSLATIONS = HEADER_TRANSLATIONS.invert
      HEADER_REVERSE_TRANSLATIONS_KEYS = Regexp.union(HEADER_REVERSE_TRANSLATIONS.keys).freeze
      EMPTY = "".force_encoding("UTF-8").freeze

      # @return [String]
      attr_reader :command

      # @return [Hash<String, String>]
      attr_reader :headers

      # @return [String]
      attr_reader :body

      # Construct a message from a command, optional headers, and a body.
      #
      # @param [String] command
      # @param [Hash<String, String>] headers
      # @param [String] body
      def initialize(command, headers = {}, body)
        @command = command || EMPTY
        @headers = headers
        @body = body || EMPTY
      end

      # Change the command of this message.
      #
      # @param [String] command
      def write_command(command)
        @command = command
      end

      # Write a single header to this message.
      #
      # @param [String] key
      # @param [String] value
      def write_header(key, value)
        # @see http://stomp.github.io/stomp-specification-1.2.html#Repeated_Header_Entries
        @headers[translate_header(key)] ||= translate_header(value)
      end

      # Write the body to this message.
      #
      # @param [String] body
      def write_body(body)
        @body = body
      end

      # @return [String] a string-representation of this message.
      def to_str
        message = "".force_encoding("UTF-8")
        message << command << "\n"

        outgoing_headers = if headers.empty? and body.include?("\x00")
          headers.merge("content-length" => "#{body.bytesize}")
        else
          headers
        end
        outgoing_headers.each do |key, value|
          message << serialize_header(key) << ":" << serialize_header(value) << "\n"
        end
        message << "\n"

        message << body << "\x00"
        message
      end

      def [](key)
        @headers[key]
      end

      def destination
        self["destination"]
      end

      private

      # @see http://stomp.github.io/stomp-specification-1.2.html#Value_Encoding
      def translate_header(value)
        value.gsub(HEADER_TRANSLATIONS_KEYS, HEADER_TRANSLATIONS)
      end

      # inverse of #translate_header
      def serialize_header(value)
        value.gsub(HEADER_REVERSE_TRANSLATIONS_KEYS, HEADER_REVERSE_TRANSLATIONS)
      end
    end
  end
end
