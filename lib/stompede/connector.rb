module Stompede
  class Connector
    include Celluloid::IO

    def safe_io
      yield
    rescue IOError
      raise Disconnected, "client disconnected"
    end

    def very_safe_io
      yield
    rescue IOError
    end

    def initialize(app)
      @app = app
      link(@app) if @app.is_a?(Celluloid::Actor)
    end

    def open(socket)
      session = Session.new(socket)
      parser = Stomp::Parser.new do |message|
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
        when "SEND"
          @app.on_send(session, message)
        when "SUBSCRIBE"
          subscription = session.subscribe(message)
          @app.on_subscribe(session, subscription, message)
        when "UNSUBSCRIBE"
          subscription = session.unsubscribe(message)
          @app.on_unsubscribe(session, subscription, message)
        end
      end

      @app.on_open(session)

      loop do
        chunk = safe_io { socket.readpartial(Stompede::BUFFER_SIZE) }
        parser.parse(chunk)
      end
    rescue Disconnected
      # no op
    rescue ClientError => e
      very_safe_io do
        headers = { "content-type" => "text/plain" }
        socket.write(Stomp::Message.new("ERROR", headers, "#{e.class}: #{e.message}\n\n#{e.backtrace.join("\n")}").to_str)
      end
    ensure
      socket.close
      session.subscriptions.each do |subscription|
        @app.on_unsubscribe(session, subscription)
      end
      @app.on_close(session)
    end
  end
end
