%%{
  machine message;

  getkey data.getbyte(p); # code for retrieving current char

  action mark {
    mark = p
  }
  action mark_key {
    mk = data.byteslice(mark, p - mark)
    mark = nil
  }
  action mark_message {
    message = Stomp::Message.new(nil, nil)
    message_size = 0
  }
  action check_message_size {
    message_size += 1
    raise MessageSizeExceeded if message_size > max_message_size
  }

  action write_command {
    message.write_command(data.byteslice(mark, p - mark))
    mark = nil
  }

  action write_header {
    message.write_header(mk, data.byteslice(mark, p - mark))
    mk = mark = nil
  }

  action write_body {
    message.write_body(data.byteslice(mark, p - mark))
    mark = nil
  }

  action finish_headers {
    if message.headers.has_key?("content-length")
      content_length = Integer(message.headers["content-length"])
    else
      content_length = nil
    end
  }

  action consume_null {
    (p - mark) < content_length if content_length
  }

  action consume_octet {
    if content_length
      (p - mark) < content_length
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

  client_commands = "SEND" | "SUBSCRIBE" | "UNSUBSCRIBE" | "BEGIN" | "COMMIT" | "ABORT" | "ACK" | "NACK" | "DISCONNECT" | "CONNECT" | "STOMP";
  server_commands = "CONNECTED" | "MESSAGE" | "RECEIPT" | "ERROR";
  command = (client_commands | server_commands) > mark % write_command . EOL;

  HEADER_ESCAPE = "\\" . ("\\" | "n" | "r" | "c");
  HEADER_OCTET = HEADER_ESCAPE | (OCTET - "\r" - "\n" - "\\" - ":");
  header_key = HEADER_OCTET+ > mark % mark_key;
  header_value = HEADER_OCTET* > mark;
  header = header_key . ":" . header_value;
  headers = (header % write_header . EOL)* % finish_headers . EOL;

  consume_body = (NULL when consume_null | ^NULL when consume_octet)*;
  body = consume_body >from(mark) % write_body <: NULL;

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
      # @yield [message] yields each message as it is parsed
      # @yieldparam message [Stomp::Message]
      def self.parse(data, state, offset = 0)
        p = offset # pointer to current character
        pe = data.bytesize # end of chunk
        message = state.message # message currently being parsed, if any
        cs = state.current_state # current state
        mk = state.mark_key # key for header currently being read
        mark = state.mark # buffered data for marks
        message_size = state.message_size # how many bytes current message contains in total
        content_length = state.content_length # content length of current message

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
          state.mark = mark
          state.message_size = message_size
          state.content_length = content_length
        end

        nil
      end

      # Construct the parser.
      def initialize
        @error = nil
        @data = nil
        @mark = nil
        @message_size = nil
        @current_state = Stomp::Parser.start
        @message = nil
        @mark_key = nil
      end

      # @return [StandardError] error raised during parsing
      attr_accessor :error

      # @return [Integer] message size accumulated so far
      attr_accessor :message_size

      # @return [Integer, nil]
      attr_accessor :content_length

      # @return [Integer] current parsing state
      attr_accessor :current_state

      # @return [Stomp::Message] stomp message currently being parsed
      attr_accessor :message

      # @return [Integer] marking in the data being processed
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
          if @data
            offset = @data.bytesize
            data = @data << data
          else
            offset = 0
            data
          end

          Parser.parse(data, self, offset) do |message|
            yield message
          end

          if mark
            @data = data
          else
            @data = nil
          end
        rescue => error
          self.error = error
          raise
        end
      end
    end
  end
end
