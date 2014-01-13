%%{
  machine message;

  # data, p, pe, eof, cs, top, stack, ts, te and act
  getkey data.getbyte(p); # code for retrieving current char

  ## Action state - needs resetting once consumed!
  action mark {
    m = p
    buffer = "".force_encoding("BINARY")
  }
  action buffer { buffer << fc }
  action mark_key {
    mk = buffer # needs reset
    m = buffer = nil
  }
  action mark_message { message = Stomp::Message.new }

  ## Action commands - should reset used state!
  action write_command {
    message.write_command(buffer)
    m = buffer = nil
  }

  action write_header {
    message.write_header(mk, buffer)
    m = mk = buffer = nil
  }

  action write_body {
    message.write_body(buffer)
    m = buffer = nil
  }

  action finish_headers {
  }

  action finish_message {
    yield message
    message = nil
  }

  ## Stomp message grammar

  NULL = "\0";
  EOL = "\r"? . "\n";
  OCTET = any;

  client_command = "CONNECT" > mark;
  command = client_command $ buffer % write_command . EOL;

  HEADER_ESCAPE = "\\" . ("\\" | "n" | "r" | "c");
  HEADER_OCTET = HEADER_ESCAPE | (OCTET - "\r" - "\n" - "\\" - ":");
  header_key = HEADER_OCTET+ > mark $ buffer % mark_key;
  header_value = HEADER_OCTET* > mark $ buffer;
  header = header_key . ":" . header_value;
  headers = (header % write_header . EOL)* % finish_headers . EOL;

  dynamic_body = (OCTET* > mark) $ buffer % write_body :> NULL;

  message = (command > mark_message) :> headers :> (dynamic_body @ finish_message);

  stream := (EOL | message)*;
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
        pe = data.bytesize # end of chunk
        eof = :ignored # end of input

        p = 0 # pointer to current character
        message = state.message # message currently being parsed, if any
        cs = state.current_state # current state
        m = state.mark # pointer to marked character (for data buffering)
        mk = state.mark_key # key for header currently being read
        buffer = state.buffer # buffered data for marks

        %% write exec;

        if cs == Stomp::Parser.error
          # build error message context
          ctx = 7
          min = [0, p - ctx].max
          cur = p - min
          err = data.byteslice(min, ctx + 1 + ctx)
          chr = err[cur]
          err[cur] = " -->#{err[cur]}<-- "

          raise ParseError.new("unexpected #{chr.inspect} in data (#{err.inspect})")
        else
          state.message = message
          state.current_state = cs
          state.mark = m
          state.mark_key = mk
          state.buffer = buffer
        end

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
        @error = nil
        @buffer = nil

        @current_state = Stomp::Parser.start
        @message = nil
        @mark = nil
        @mark_key = nil
      end

      # @return [Integer] maximum buffer size for parsed values
      attr_reader :buffer_size

      # @return [Integer] maximum message size for parsed messages
      attr_reader :message_size

      # @return [StandardError] error raised during parsing
      attr_accessor :error

      # @return [String] binary string of current parsing buffer
      attr_accessor :buffer

      # @return [Integer] current parsing state
      attr_accessor :current_state

      # @return [Stomp::Message] stomp message currently being parsed
      attr_accessor :message

      # @return [Integer] pointer to beginning of current buffer
      attr_accessor :mark

      # @return [String] header key currently being parsed
      attr_accessor :mark_key

      # Parse a chunk of data. Retains state beteween invocations.
      #
      # @param [String] data
      # @raise [ParseError]
      def parse(data)
        raise error if error

        begin
          Parser.parse(data, self) do |message|
            yield message
          end
        rescue => error
          self.error = error
          raise
        end
      end
    end
  end
end
