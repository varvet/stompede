# wraps a socket and raises predictable exceptions
module Stompede
  class SafeSocket
    def initialize(socket)
      @socket = socket
    end

    def read
      @socket.readpartial(Stompede::BUFFER_SIZE)
    rescue IOError
      raise Disconnected
    end

    def write(text)
      @socket.write(text.to_str)
    rescue IOError
      raise Disconnected
    end

    def safe_write(text)
      write(text)
    rescue Disconnected
    end

    def close
      @socket.close
    rescue IOError
    end
  end
end
