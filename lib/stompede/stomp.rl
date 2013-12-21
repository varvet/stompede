%%{
  machine Message;

  # data, p, pe, eof, cs, top, stack, ts, te and act

  action mark { m = p }
  action write_command { message.command = data[m..p] }

  action store_key { key = data[m..p] }
  action write_header { message.headers[key] = data[m..p] }

  NULL = "\0";
  LF = "\n";
  CR = "\r";
  EOL = CR? LF;
  OCTET = any;
  HEADER_OCTET = OCTET - CR - LF - ":";

  command_name = "CONNECT";
  command = command_name > mark @ write_command;

  header_key = HEADER_OCTET+ > mark @ store_key;
  header_value = HEADER_OCTET* > mark @ write_header;
  header = header_key ":" header_value EOL;

  message := command EOL header* EOL NULL;
}%%

module Stompede
  module Stomp
    # this manipulates the singleton class of our context,
    # so we do not want to run this code very often or we
    # bust our ruby method caching
    %% write data noprefix;

    class << self
      # @param [String] data
      # @return [Stomp::Message]
      def parse(data)
        # re-encode the input as BINARY to be able to refer
        # on the byte-level with data[i].ord
        data = data.force_encoding("BINARY")

        # this is where our parsed components end up
        message = Stomp::Message.new

        p = 0 # pointer to current character
        m = 0 # pointer to marked character (for buffering)
        pe = data.length # pointer to end of input
        cs = start # current starting state

        # write out the ragel state machine parser
        %% write exec;

        # if parsing parsed a complete message, return it
        message if cs >= first_final
      end
    end
  end
end
