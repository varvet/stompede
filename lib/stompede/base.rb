module Stompede
  class Base
    include Celluloid::IO

    finalizer :cleanup_session

    attr_reader :session

    def initialize(socket)
      @session = Session.new(self, socket)
      yield(Actor.current) if block_given?
      async.open_session
    end

    def schedule
      yield
    end
    execute_block_on_receiver :schedule

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

  private

    def open_session
      @session.send(:open)
    end

    def cleanup_session
      @session.send(:cleanup)
    end
  end
end
