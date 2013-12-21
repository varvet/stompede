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

  message := (command > Mark @ { @message.command = consume }) EOL EOL NULL;
}%%

module Stompede
  module Stomp
    %% write data;

    class << self
      # @param [String] data
      # @return [Stomp::Message]
      def parse(data)
        @message = Stomp::Message.new

        @_data = data.force_encoding("BINARY")
        @_p = 0
        pe = data.length
        cs = self.Message_start

        %% write exec;

        @message
      end

      def mark
        @mark = @_p
      end

      def consume
        @_data[@mark..@_p].force_encoding("UTF-8")
      end
    end
  end
end
