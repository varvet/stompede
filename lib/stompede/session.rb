module Stompede
  class Session
    def initialize(app, socket)
      @app = app
      @app_actor = Celluloid::Actor.current
      @socket = socket
      @subscriptions = {}
    end

    def subscriptions
      @app_actor.schedule { @subscriptions.values }
    end

    def write(value)
      @app_actor.schedule { @socket.write(value) }
    end

    def safe_write(value)
      @app_actor.schedule { @socket.safe_write(value) }
    end

    def close
      @app_actor.schedule { @socket.close }
    end

  private

    def cleanup
      @socket.close
      @subscriptions.each do |id, subscription|
        @app.on_unsubscribe(subscription, nil)
      end
      @app.on_close
    end

    def open
      parser = StompParser::Parser.new

      @app.on_open

      loop do
        parser.parse(@socket.read) do |frame|
          frame = Frame.new(self, frame.command, frame.headers, frame.body)
          frame.validate!
          case frame.command
          when :connect, :disconnect, :send
            dispatch(frame.command, frame)
          when :subscribe
            subscription = subscribe(frame)
            dispatch(:subscribe, subscription, frame)
          when :unsubscribe
            subscription = unsubscribe(frame)
            dispatch(:unsubscribe, subscription, frame)
          end
        end
      end
    rescue Disconnected, ClientError, StompParser::Error => e
      @socket.safe_write(ErrorFrame.new(e))
      @app.terminate
    rescue => e
      @socket.safe_write(ErrorFrame.new(e))
      raise
    end

    def dispatch(callback, *args, frame)
      @app.send(:"on_#{callback}", *args, frame)
      frame.receipt! unless frame.detached?
    rescue => e
      frame.error!(e) unless frame.detached?
      raise e
    end

    def subscribe(frame)
      subscription = Subscription.new(self, frame)
      if @subscriptions[subscription.id]
        raise ClientError, "subscription with id #{subscription.id.inspect} already exists"
      end
      @subscriptions[subscription.id] = subscription
      subscription
    end

    def unsubscribe(frame)
      subscription = Subscription.new(self, frame)
      unless @subscriptions[subscription.id]
        raise ClientError, "subscription with id #{subscription.id.inspect} does not exist"
      end
      @subscriptions.delete(subscription.id)
    end
  end
end
