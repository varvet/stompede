%%{
  machine Message;

  variable data @_data;
  variable p    @_p;

  # data, p, pe, eof, cs, top, stack, ts, te and act

  # Actions.
  action Mark { mark }

  # Common constants.
  NULL = "\0";
  LF = "\n";
  CR = "\r";
  EOL = CR? LF;

  # Message components.
  command = "CONNECT";
  consume_command = command > Mark @ { @message.command = consume_utf8 };

  message := consume_command EOL EOL NULL;
}%%

module Stompede
  module Stomp
    %% write data noprefix;

    class << self
      # @param [String] data
      # @return [Stomp::Message]
      def parse(data)
        @message = Stomp::Message.new

        @_data = data.force_encoding("BINARY")
        @_p = 0
        pe = data.length
        cs = start

        %% write exec;

        @message if cs >= first_final
      end

      def mark
        @mark = @_p
      end

      def consume_utf8
        string = @_data[@mark..@_p].force_encoding("UTF-8")
        @mark = nil # signal the marked data is consumed
        string
      end
    end
  end
end
