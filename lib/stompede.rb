require "celluloid"
require "celluloid/io"

require "securerandom"

require "stompede/version"

require "stompede/error"
require "stompede/stomp/parser"
require "stompede/stomp/message"

begin
  require "stompede/stomp/parser_native"
rescue LoadError
  # Native parser not available, fall back to pure-ruby implementation.
end

module Stompede
  BUFFER_SIZE = 10 * 1024
  STOMP_VERSION = "1.2" # version of the STOMP protocol we support

  class Session
    def initialize(socket)
      @socket = socket
    end
  end

  class Base
    include Celluloid

    def on_open(session)
    end

    def on_connect(session, frame)
    end

    def on_subscribe(session, subscription, frame)
    end

    def on_send(session, frame)
    end

    def on_unsubscribe(session, subscription, frame)
    end

    def on_disconnect(session, frame)
    end

    def on_close(session)
    end
  end

  class Connector
    include Celluloid::IO

    class Disconnected < IOError; end

    def safe_io
      yield
    rescue IOError
      raise Disconnected, "client disconnected"
    end

    def initialize(app)
      @app = app
      link(@app) if @app.is_a?(Celluloid::Actor)
    end

    def open(socket)
      session = Session.new(socket)
      parser = Stomp::Parser.new

      @app.on_open(session)

      loop do
        chunk = safe_io { socket.readpartial(Stompede::BUFFER_SIZE) }
        parser.parse(chunk) do |message|
          case message.command
          when "CONNECT"
            begin
              @app.on_connect(session, message)
            rescue => e
              headers = {
                "version" => STOMP_VERSION,
                "content-type" => "text/plain"
              }
              safe_io { socket.write(Stomp::Message.new("ERROR", headers, "#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}").to_str) }
              raise
            else
              headers = {
                "version" => STOMP_VERSION,
                "server" => "Stompede/#{Stompede::VERSION}",
                "session" => SecureRandom.uuid
              }
              safe_io { socket.write(Stomp::Message.new("CONNECTED", headers, "").to_str) }
            end
          when "DISCONNECT"
            @app.on_disconnect(session, message)
          end
        end
      end
    rescue Disconnected
      # ignore
    ensure
      socket.close
      @app.on_close(session)
    end
  end
end
