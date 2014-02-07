%%{
  machine message;

  getkey data.getbyte(p);

  action mark {
    mark = p
  }
  action mark_key {
    mark_key = data.byteslice(mark, p - mark)
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
    mark_message.write_command(data.byteslice(mark, p - mark))
    mark = nil
  }

  action write_header {
    mark_message.write_header(mark_key, data.byteslice(mark, p - mark))
    mark_key = mark = nil
  }

  action write_body {
    mark_message.write_body(data.byteslice(mark, p - mark))
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
          @cs = nil
          @mark = nil
          @mark_key = nil
          @mark_message = nil
          @mark_message_size = nil
          @mark_content_length = nil
        end

        # You want documentation? HAHA.
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
      # @param [String] data
      # @param [State] state previous parser state, or nil for initial state
      # @param [Integer] max_message_size
      # @yield [message] yields each message as it is parsed
      # @yieldparam message [Stomp::Message]
      def self._parse(data, offset, state, max_message_size)
        pe = data.bytesize # special

        p = offset
        cs = state.cs
        mark = state.mark
        mark_key = state.mark_key
        mark_message = state.mark_message
        mark_message_size = state.mark_message_size
        mark_content_length = state.mark_content_length

        %% write exec;

        state.p = p
        state.cs = cs
        state.mark = mark
        state.mark_key = mark_key
        state.mark_message = mark_message
        state.mark_message_size = mark_message_size
        state.mark_content_length = mark_content_length

        state.mark || pe
      end

      def initialize(max_message_size, &handler)
        @state = State.new
        @state.cs = RubyParser.start
        @handler = handler

        @max_message_size = max_message_size
      end

      def parse(chunk)
        unless @error
          if @chunk
            offset = @chunk.bytesize
            chunk = @chunk << chunk
          else
            offset = 0
          end

          consumed_until = self.class._parse(chunk, offset, @state, @max_message_size, &@handler)

          if @state.cs == RubyParser.error
            @error = Stomp::Parser.build_error(chunk, @state.p)
          elsif consumed_until < chunk.bytesize
            @chunk = chunk
          else
            @chunk = nil
          end
        end

        raise @error if @error
      end
    end
  end
end
