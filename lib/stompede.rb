require "stomp_parser"
require "celluloid"
require "celluloid/io"

require "delegate"
require "securerandom"

require "stompede/version"
require "stompede/ack"
require "stompede/light_stomplet"
require "stompede/stomplet"
require "stompede/dispatcher"
require "stompede/connector"
require "stompede/frame"
require "stompede/error_frame"
require "stompede/session"
require "stompede/subscription"

module Stompede
  STOMP_VERSION = "1.2" # version of the STOMP protocol we support

  class Nack < StandardError; end
  class Error < StandardError; end
  class ClientError < Error; end
  class Disconnected < Error; end
  class TimeoutError < Error; end

  class TCPServer
    def initialize(app_klass, options = {})
      @connector = Connector.new(app_klass, options)
    end

    def listen(*args)
      server = ::TCPServer.new(*args)
      loop do
        socket = server.accept
        @connector.async.connect(Celluloid::IO::TCPSocket.new(socket))
      end
    end
  end

  class WebSocketServer
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
