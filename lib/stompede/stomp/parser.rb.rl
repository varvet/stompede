%%{
  machine message;

  # data, p, pe, eof, cs, top, stack, ts, te and act

  action mark { m = p }
  action mark_key { mk = data[m...p] }

  action write_command { message.write_command(data[m...p]) }
  action write_header { message.write_header(mk, data[m...p]) }
  action write_body { message.write_body(data[m...p]) }

  action init_message {
    message = Stomp::Message.new
  }
  action finish_headers {}
  action finish_message {
    return message
  }

  NULL = "\0";
  EOL = "\r"? . "\n";
  OCTET = any;

  client_command = "CONNECT" > mark;
  command = client_command % write_command . EOL;

  HEADER_ESCAPE = "\\" . ("\\" | "n" | "r" | "c");
  HEADER_OCTET = HEADER_ESCAPE | (OCTET - "\r" - "\n" - "\\" - ":");
  header_key = HEADER_OCTET+ > mark % mark_key;
  header_value = HEADER_OCTET* > mark;
  header = header_key . ":" . header_value;
  headers = (header % write_header . EOL)* % finish_headers . EOL;

  dynamic_body = (OCTET* > mark) % write_body :> NULL;

  message := (command > init_message) :> headers :> (dynamic_body @ finish_message);
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
      # @return [Stomp::Message, nil]
      def self.parse(data)
        data = data.force_encoding("BINARY") # input data, referenced by data[i]
        message = nil # handle to the message currently being parsed, if any
        p = 0 # pointer to current character
        pe = data.length # end of input
        cs = Stomp::Parser.start # current state
        m = 0 # pointer to marked character (for buffering)
        mk = nil # key for header currently being read

        # write out the ragel state machine parser
        %% write exec;

        # if parsing parsed a complete message, return it
        message if cs >= Stomp::Parser.first_final
      end
    end
  end
end
