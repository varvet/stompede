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
      @socket.close rescue nil
      @subscriptions.each do |id, subscription|
        @app.on_unsubscribe(subscription, nil)
      end
      @app.on_close
    end

    def open
      parser = StompParser::Parser.new

      @app.on_open

      loop do
        chunk = safe_io { @socket.readpartial(Stompede::BUFFER_SIZE) }
        parser.parse(chunk) do |frame|
          frame = Frame.new(frame.command, frame.headers, frame.body)
          case frame.command
          when "CONNECT", "STOMP"
            unless frame["accept-version"].split(",").include?(STOMP_VERSION)
              raise ClientError.new("client must support STOMP version #{STOMP_VERSION}", version: STOMP_VERSION)
            end
            @app.on_connect(frame)
            headers = {
              "version" => STOMP_VERSION,
              "server" => "Stompede/#{Stompede::VERSION}",
              "session" => SecureRandom.uuid
            }
            safe_io { @socket.write(StompParser::Frame.new("CONNECTED", headers, "").to_str) }
          when "DISCONNECT"
            receipt(frame) { @app.on_disconnect(frame) }
          when "SEND"
            receipt(frame) { @app.on_send(frame) }
          when "SUBSCRIBE"
            subscription = subscribe(frame)
            receipt(frame) { @app.on_subscribe(subscription, frame) }
          when "UNSUBSCRIBE"
            subscription = unsubscribe(frame)
            receipt(frame) { @app.on_unsubscribe(subscription, frame) }
          end
        end
      end
    rescue HandlerError => e
      raise e.error
    rescue Disconnected
      @app.terminate
    rescue ClientError, StompParser::Error => e
      write_error(e)
      @app.terminate
    rescue => e
      write_error(e)
      raise
    end

    def receipt(frame)
      yield
      if frame["receipt"] and not frame.detached?
        safe_io { @socket.write(StompParser::Frame.new("RECEIPT", { "receipt-id" => frame["receipt"] }, "").to_str) }
      end
    rescue => e
      if frame["receipt"] and not frame.detached?
        write_error(e, "receipt-id" => frame["receipt"])
      else
        write_error(e)
      end
      raise HandlerError.new(e)
    end

    def write_error(error, headers={})
      body = "#{error.class}: #{error.message}\n\n#{error.backtrace.join("\n")}"
      headers["content-type"] = "text/plain"
      headers.merge!(error.headers) if error.respond_to?(:headers)

      @socket.write(StompParser::Frame.new("ERROR", headers, body).to_str)
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
  end
end
