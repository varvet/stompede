module Stompede
  class Error < StandardError
  end

  class ClientError < Error
    attr_reader :headers

    def initialize(message, headers = {})
      super(message)
      @headers = headers
    end
  end

  class Disconnected < Error
  end
end
