module Stompede
  class Stomplet
    include Celluloid

    finalizer :cleanup

    attr_reader :session

    def initialize(session)
      @session = session
    end

    def on_open
    end

    def on_connect(frame)
    end

    def on_subscribe(subscription, frame)
    end

    def on_send(frame)
    end

    def on_unsubscribe(subscription, frame)
    end

    def on_disconnect(frame)
    end

    def on_close
    end

    def dispatch(command, *args)
      public_send(:"on_#{command}", *args)
    rescue ClientError => e
      session.error(e)
      terminate
    rescue Disconnect => e
      terminate
    end

    def cleanup
      @session.subscriptions.each do |subscription|
        dispatch(:unsubscribe, subscription, nil)
      end
      dispatch(:close)
    end
  end
end
