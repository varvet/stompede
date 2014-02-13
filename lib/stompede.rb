require "stomp_parser"
require "celluloid"
require "celluloid/io"

require "delegate"
require "securerandom"

require "stompede/version"
require "stompede/error"

require "stompede/base"
require "stompede/safe_socket"
require "stompede/frame"
require "stompede/error_frame"
require "stompede/session"
require "stompede/subscription"

module Stompede
  BUFFER_SIZE = 10 * 1024
  STOMP_VERSION = "1.2" # version of the STOMP protocol we support

  class TCPServer
    def initialize(app_klass)
      @app_klass = app_klass
    end

    def listen(*args)
      server = ::TCPServer.new(*args)
      loop do
        socket = server.accept
        @app_klass.new(Celluloid::IO::TCPSocket.new(socket))
      end
    end
  end

  class WebsocketServer
    def initialize(app_klass)
      @app_klass = app_klass
    end

    class Socket < SimpleDelegator
      def initialize(websocket)
        super(websocket)
      end

      def readpartial(*args)
        read
      end
    end

    def listen(*args)
      require "reel"
      Reel::Server.run(*args) do |connection|
        connection.each_request do |request|
          if request.websocket?
            @app_klass.new(Socket.new(request.websocket))
          else
            request.respond :ok, "Stompede"
          end
        end
      end
    end
  end
end
