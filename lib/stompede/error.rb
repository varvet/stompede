module Stompede
  class Nack < StandardError; end
  class Error < StandardError; end
  class ClientError < Error; end
  class Disconnected < Error; end
end
