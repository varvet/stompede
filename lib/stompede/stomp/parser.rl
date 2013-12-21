%%{
  machine message;

  # data, p, pe, eof, cs, top, stack, ts, te and act

  action mark { m = p }
  action write_command { message.write_command(data[m...p]) }

  action store_key { key = data[m...p] }
  action write_header { message.write_header(key, data[m...p]) }

  NULL = "\0";
  LF = "\n";
  CR = "\r";
  EOL = CR? LF;
  OCTET = any;
  HEADER_ESCAPE = "\\" ("\\" | "n" | "r" | "c");
  HEADER_OCTET = HEADER_ESCAPE | OCTET - CR - LF - ":" - "\\";

  command_name = "CONNECT";
  command = command_name > mark % write_command;

  header_key = HEADER_OCTET+ > mark % store_key;
  header_value = HEADER_OCTET* > mark % write_header;
  header = header_key ":" header_value EOL;

  message := command EOL header* EOL NULL;
}%%

module Stompede
  module Stomp
    class Parser
      # this manipulates the singleton class of our context,
      # so we do not want to run this code very often or we
      # bust our ruby method caching
      %% write data noprefix;

      # Parse a chunk of Stomp-formatted data into a Message.
      #
      # @param [String] data
      # @return [Stomp::Message]
      def self.parse(data)
        # re-encode the input as BINARY to be able to refer
        # on the byte-level with data[i].ord
        data = data.force_encoding("BINARY")

        # this is where our parsed components end up
        message = Stomp::Message.new

        p = 0 # pointer to current character
        pe = data.length # pointer to end of input
        cs = Stomp::Parser.start # current starting state
        m = 0 # pointer to marked character (for buffering)

        # write out the ragel state machine parser
        %% write exec;

        # if parsing parsed a complete message, return it
        message if cs >= Stomp::Parser.first_final
      end
    end
  end
end
