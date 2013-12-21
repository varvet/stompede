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
    %% write data noprefix;

    class << self
      # @param [String] data
      # @return [Stomp::Message]
      def parse(data)
        message = Stomp::Message.new

        data = data.force_encoding("BINARY")
        p = 0
        pe = data.length
        cs = start

        %% write exec;

        message if cs >= first_final
      end
    end
  end
end
