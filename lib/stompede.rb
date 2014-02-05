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

    def initialize(app)
      @app = app
      link(@app)
    end

    def open(socket)
      session = Session.new(socket)
      parser = Stomp::Parser.new

      @app.on_open(session)

      loop do
        chunk = socket.readpartial(Stompede::BUFFER_SIZE)
        parser.parse(chunk) do |message|
          if message.command == "CONNECT"
            @app.on_connect(session, message)
            headers = {
              "version" => "1.2",
              "server" => "Stompede/#{Stompede::VERSION}",
              "session" => SecureRandom.uuid
            }
            socket.write(Stomp::Message.new("CONNECTED", headers, "").to_str)
          end
          #@app.dispatch(message, session)
        end
      end
    rescue => e
      @app.on_close(session) rescue nil
      raise unless e.is_a?(EOFError)
    end
  end
end
