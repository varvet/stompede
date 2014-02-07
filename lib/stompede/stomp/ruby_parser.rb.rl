%%{
  machine message;

  getkey chunk.getbyte(p);

  action mark {
    mark = p
  }
  action mark_key {
    mark_key = chunk.byteslice(mark, p - mark)
    mark = nil
  }
  action mark_message {
    mark_message = Stomp::Message.new(nil, nil)
    mark_message_size = 0
  }
  action check_message_size {
    mark_message_size += 1
    raise MessageSizeExceeded if mark_message_size > max_message_size
  }

  action write_command {
    mark_message.write_command(chunk.byteslice(mark, p - mark))
    mark = nil
  }

  action write_header {
    mark_message.write_header(mark_key, chunk.byteslice(mark, p - mark))
    mark_key = mark = nil
  }

  action write_body {
    mark_message.write_body(chunk.byteslice(mark, p - mark))
    mark = nil
  }

  action finish_headers {
    mark_content_length = mark_message.content_length
  }

  action consume_null {
    (p - mark) < mark_content_length if mark_content_length
  }

  action consume_octet {
    if mark_content_length
      (p - mark) < mark_content_length
    else
      true
    end
  }

  action finish_message {
    yield mark_message
    mark_message = nil
  }

  include message_common "parser_common.rl";
}%%

module Stompede
  module Stomp
    class RubyParser
      class State
        def initialize
          @p = 0
          @cs = RubyParser.start
          @mark = nil
          @mark_key = nil
          @mark_message = nil
          @mark_message_size = nil
          @mark_content_length = nil
        end

        # You want documentation? HAHA.
        attr_accessor :chunk
        attr_accessor :p
        attr_accessor :cs
        attr_accessor :error
        attr_accessor :mark
        attr_accessor :mark_key
        attr_accessor :mark_message
        attr_accessor :mark_message_size
        attr_accessor :mark_content_length
      end

      # this manipulates the singleton class of our context,
      # so we do not want to run this code very often or we
      # bust our ruby method caching
      %% write data noprefix;

      # Parse a chunk of Stomp-formatted data into a Message.
      #
      # @param [String] chunk
      # @param [State] state previous parser state, or nil for initial state
      # @param [Integer] max_message_size
      # @yield [message] yields each message as it is parsed
      # @yieldparam message [Stomp::Message]
      def self._parse(chunk, state, max_message_size)
        if state.chunk
          p = state.chunk.bytesize
          chunk = state.chunk << chunk
        else
          p = 0
        end

        pe = chunk.bytesize # special

        cs = state.cs
        mark = state.mark
        mark_key = state.mark_key
        mark_message = state.mark_message
        mark_message_size = state.mark_message_size
        mark_content_length = state.mark_content_length

        %% write exec;

        if mark
          state.p = chunk.bytesize
          state.chunk = chunk
        else
          state.p = 0
          state.chunk = nil
        end

        state.cs = cs
        state.mark = mark
        state.mark_key = mark_key
        state.mark_message = mark_message
        state.mark_message_size = mark_message_size
        state.mark_content_length = mark_content_length

        if cs == RubyParser.error
          Stomp.build_parse_error(chunk, p)
        else
          nil
        end
      end

      def initialize(max_message_size = Stomp.max_message_size)
        @state = State.new
        @max_message_size = Integer(max_message_size)
      end

      # Parse a chunk.
      #
      # @param [String] chunk
      # @yield [message]
      # @yieldparam [Stomp::Message] message
      def parse(chunk)
        @error ||= self.class._parse(chunk, @state, @max_message_size) do |message|
          yield message
        end

        raise @error if @error
      end
    end
  end
end
