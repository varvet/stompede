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
    include Celluloid::IO

    def initialize(app_klass, options = {})
      @connector = Connector.new(app_klass, options)
    end

    def message_all(*args)
      @connector.message_all(*args)
    end

    def listen(*args)
      @server = Celluloid::IO::TCPServer.new(*args)
      async.accept
    end

    def close
      @server.close if @server
    end

  private

    def accept
      loop do
        @connector.async.connect(@server.accept)
      end
    end
  end

  class WebSocketServer
    def initialize(app_klass, options = {})
      @connector = Connector.new(app_klass, options)
    end

    class Socket < SimpleDelegator
      def initialize(websocket)
        super(websocket)
      end

      def readpartial(*args)
        read
      end
    end

    def message_all(*args)
      @connector.message_all(*args)
    end

    def listen(*args)
      require "reel"
      @server = Reel::Server.supervise(*args) do |connection|
        connection.each_request do |request|
          if request.websocket?
            @connector.async.connect(Socket.new(request.websocket))
          else
            request.respond :ok, "Stompede"
          end
        end
      end
    end

    def close
      @server.terminate if @server
    rescue Celluloid::DeadActorError
    end
  end
end
