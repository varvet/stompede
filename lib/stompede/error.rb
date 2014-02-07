module Stompede
  class Error < StandardError
  end

  class ClientError < Error
  end

  class Disconnected < Error
  end
end
