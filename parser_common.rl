%%{
  machine message_common;

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
