module Stompede
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
          when "SEND"
            @app.on_send(session, message)
          when "SUBSCRIBE"
            subscription = nil
            @app.on_subscribe(session, subscription, message)
          when "UNSUBSCRIBE"
            subscription = nil
            @app.on_unsubscribe(session, subscription, message)
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
