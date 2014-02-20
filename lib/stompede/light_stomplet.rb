module Stompede
  class LightStomplet
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
    end
  end
end
