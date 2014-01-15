%%{
  machine message;

  # data, p, pe, eof, cs, top, stack, ts, te and act
  getkey data.getbyte(p); # code for retrieving current char

  ## Action state - needs resetting once consumed!
  action mark {
    buffer = "".force_encoding("BINARY")
  }
  action buffer {
    buffer << fc
  }
  action mark_key {
    mk = buffer # needs reset
    buffer = nil
  }
  action mark_message {
    message = Stomp::Message.new(nil, nil)
    message_size = 0
  }
  action check_message_size {
    message_size += 1
    raise MessageSizeExceeded if message_size > max_message_size
  }

  ## Action commands - should reset used state!
  action write_command {
    message.write_command(buffer)
    buffer = nil
  }

  action write_header {
    message.write_header(mk, buffer)
    mk = buffer = nil
  }

  action write_body {
    message.write_body(buffer)
    buffer = nil
  }

  action finish_headers {
    if message.headers.has_key?("content-length")
      content_length = Integer(message.headers["content-length"])
    end
  }

  action consume_null {
    buffer.length < content_length if content_length
  }

  action consume_octet {
    if content_length
      buffer.length < content_length
    else
      true
    end
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

  body = ((NULL when consume_null | ^NULL when consume_octet)* $ buffer) >to(mark) % write_body <: NULL;

  message = ((command > mark_message) :> headers :> (body @ finish_message)) $ check_message_size;

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

      class << self
        # @attr [Integer] maximum size (in bytes) a message may become before raising MessageSizeExceeded.
        attr_accessor :max_message_size
      end

      self.max_message_size = 1024 * 100 # 100KB

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
        mk = state.mark_key # key for header currently being read
        buffer = state.buffer # buffered data for marks
        message_size = state.message_size
        content_length = state.content_length

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
          state.mark_key = mk
          state.buffer = buffer
          state.message_size = message_size
          state.content_length = content_length
        end

        nil
      end

      # Construct the parser.
      def initialize
        @error = nil
        @buffer = nil
        @message_size = nil
        @current_state = Stomp::Parser.start
        @message = nil
        @mark_key = nil
      end

      # @return [StandardError] error raised during parsing
      attr_accessor :error

      # @return [Integer] message size accumulated so far
      attr_accessor :message_size

      # @return [String] binary string of current parsing buffer
      attr_accessor :buffer

      # @return [Integer, nil]
      attr_accessor :content_length

      # @return [Integer] current parsing state
      attr_accessor :current_state

      # @return [Stomp::Message] stomp message currently being parsed
      attr_accessor :message

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
