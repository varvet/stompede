%%{
  machine message;

  getkey data.getbyte(p); # code for retrieving current char

  # data, p, pe, eof, cs, top, stack, ts, te and act

  action mark { m = p }
  action mark_key { mk = data.byteslice(m, p) }

  action write_command { message.write_command(data.byteslice(m, p)) }
  action write_header { message.write_header(mk, data.byteslice(m, p)) }
  action write_body { message.write_body(data.byteslice(m, p)) }

  action init_message {
    message = Stomp::Message.new
  }
  action finish_headers {}
  action finish_message {
    return message
  }

  NULL = "\0";
  EOL = "\r"? . "\n";
  OCTET = any;

  client_command = "CONNECT" > mark;
  command = client_command % write_command . EOL;

  HEADER_ESCAPE = "\\" . ("\\" | "n" | "r" | "c");
  HEADER_OCTET = HEADER_ESCAPE | (OCTET - "\r" - "\n" - "\\" - ":");
  header_key = HEADER_OCTET+ > mark % mark_key;
  header_value = HEADER_OCTET* > mark;
  header = header_key . ":" . header_value;
  headers = (header % write_header . EOL)* % finish_headers . EOL;

  dynamic_body = (OCTET* > mark) % write_body :> NULL;

  message := (command > init_message) :> headers :> (dynamic_body @ finish_message);
}%%

module Stompede
  module Stomp
    # Provides an API for running parsers.
    #
    # It:
    # - provides a .parse method which remembers state between invocations
    # - buffering of data between chunks
    class Parser
      # this manipulates the singleton class of our context,
      # so we do not want to run this code very often or we
      # bust our ruby method caching
      %% write data noprefix;

      # Parse a chunk of Stomp-formatted data into a Message.
      #
      # @param [String] data
      # @param [Parser] state
      # @return [Stomp::Message, nil]
      def self.parse(data, state)
        pe = data.length # end of chunk
        eof = :ignored # end of input

        p = state.cursor # pointer to current character
        message = state.message # message currently being parsed, if any
        cs = state.current_state # current state
        m = state.mark # pointer to marked character (for data buffering)
        mk = state.mark_key # key for header currently being read

        %% write exec;

        state.cursor = p
        state.message = message
        state.current_state = cs
        state.mark = m
        state.mark_key = mk

        nil
      end

      # Construct the parser.
      #
      # The buffer_size parameter determines how big the largest
      # chunk of data may become. This includes commands, header
      # keys, header values, and the body. If this size is reached,
      # the parser will throw a #{BufferLimitExceeded} error.
      #
      # The message_size parameter determines how big the largest
      # message may become. This includes all of the content in the
      # message being parsed. If this size is reached for an individual
      # message, the parser will throw a #{MessageSizeExceeded} error.
      #
      # @param [Integer] buffer_size (10K) maximum buffer size
      # @param [Integer] message_size (buffer_size) maximum message size
      def initialize(buffer_size = 1024 * 1024, message_size = buffer_size)
        @buffer_size = buffer_size
        @message_size = message_size

        @cursor = 0
        @current_state = Stomp::Parser.start
        @message = nil
        @mark = 0
        @mark_key = nil
      end

      # @return [Integer] maximum buffer size for parsed values
      attr_reader :buffer_size

      # @return [Integer] maximum message size for parsed messages
      attr_reader :message_size

      # @return [Integer] index of parsing cursor in data
      attr_accessor :cursor

      # @return [Integer] current parsing state
      attr_accessor :current_state

      # @return [Stomp::Message] stomp message currently being parsed
      attr_accessor :message

      # @return [Integer] index of parsing cursor in data
      attr_accessor :mark

      # @return [Integer] index of parsing cursor in data
      attr_accessor :mark_key

      # @return [Integer] index of parsing cursor in data
      # @return [Integer] index of parsing cursor in data
      def parse(data)
        Parser.parse(data, self)
      end
    end
  end
end
