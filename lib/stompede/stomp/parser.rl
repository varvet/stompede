module Stompede
  module Stomp
    %%{
      machine Message;

      NULL = "\0";
      LF = "\n";
      CR = "\r";
      EOL = CR? LF;
      OCTET = any;

      client_command = "SEND" | "SUBSCRIBE" | "UNSUBSCRIBE" | "BEGIN" | "COMMIT" | "ABORT" | "ACK" | "NACK" | "DISCONNECT" | "CONNECT" | "STOMP";
      server_command = "CONNECTED" | "MESSAGE" | "RECEIPT" | "ERROR";
      command = client_command | server_command;

      header_component = (OCTET - CR - LF - ":")+;
      header_name = header_component+;
      header_value = header_component*;
      header = header_name+ ":" header_value;

      frame = command EOL (header EOL)* EOL OCTET* NULL;

      main := frame;
    }%%

    def self.parse(message)
      %% write data;
      %% write init;
      %% write exec;
    end
  end
end
