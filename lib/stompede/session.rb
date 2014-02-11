module Stompede
  class Session
    def initialize(app, socket)
      @app = app
      @app_actor = Celluloid::Actor.current
      @socket = socket
      @subscriptions = {}
    end

    def subscriptions
      @app_actor.schedule do
        @subscriptions.values
      end
    end

    def write(value)
      @app_actor.schedule do
        @socket.write(value.to_str)
      end
    end

    def close
      @app_actor.schedule do
        @socket.close
      end
    end

  private

    def cleanup
      very_safe_io { @socket.close }
      @subscriptions.each do |id, subscription|
        @app.on_unsubscribe(subscription, nil)
      end
      @app.on_close
    end

    def open
      parser = Stomp::Parser.new

      @app.on_open

      loop do
        chunk = safe_io { @socket.readpartial(Stompede::BUFFER_SIZE) }
        parser.parse(chunk) do |message|
          case message.command
          when "CONNECT"
            @app.on_connect(message)
            headers = {
              "version" => STOMP_VERSION,
              "server" => "Stompede/#{Stompede::VERSION}",
              "session" => SecureRandom.uuid
            }
            safe_io { @socket.write(Stomp::Message.new("CONNECTED", headers, "").to_str) }
          when "DISCONNECT"
            @app.on_disconnect(message)
          when "SEND"
            @app.on_send(message)
          when "SUBSCRIBE"
            subscription = subscribe(message)
            @app.on_subscribe(subscription, message)
          when "UNSUBSCRIBE"
            subscription = unsubscribe(message)
            @app.on_unsubscribe(subscription, message)
          end
        end
      end
    rescue Disconnected
      @app.terminate
    rescue ClientError, Stomp::Error => e
      write_error(e)
      @app.terminate
    rescue => e
      write_error(e)
      raise
    end

    def write_error(error)
      body = "#{error.class}: #{error.message}\n\n#{error.backtrace.join("\n")}"
      headers = { "content-type" => "text/plain" }
      @socket.write(Stomp::Message.new("ERROR", headers, body).to_str)
    rescue IOError
      # ignore, as per STOMP spec, the connection might already be gone.
    end

    def subscribe(frame)
      subscription = Subscription.new(self, frame)
      subscription.validate!
      if @subscriptions[subscription.id]
        raise ClientError, "subscription with id #{subscription.id.inspect} already exists"
      end
      @subscriptions[subscription.id] = subscription
      subscription
    end

    def unsubscribe(frame)
      subscription = Subscription.new(self, frame)
      subscription.validate!
      unless @subscriptions[subscription.id]
        raise ClientError, "subscription with id #{subscription.id.inspect} does not exist"
      end
      @subscriptions.delete(subscription.id)
    end

    def safe_io
      yield
    rescue IOError
      raise Disconnected, "client disconnected"
    end

    def very_safe_io
      yield
    rescue IOError
    end
  end
end
