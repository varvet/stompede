module Stompede
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
end
