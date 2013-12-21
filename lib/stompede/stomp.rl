%%{
  machine Message;

  NULL = "\0";
  LF = "\n";
  CR = "\r";
  EOL = CR? LF;

  command = "CONNECT";

  frame = command EOL;

  main := frame;
}%%

module Stompede
  module Stomp
    %% write data;

    # @param [String] message
    def self.parse(message)
      data = message.unpack("c*")

      p = 0
      pe = data.length
      cs = self.Message_start

      %% write exec;

      [p, pe, cs]
    end
  end
end
