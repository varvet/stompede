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
    end

    def raw_dispatch(frame)
      frame.validate!

      case frame.command
      when :connect, :disconnect, :send
        dispatch(frame.command, frame)
      when :subscribe
        subscription = session.subscribe(frame)
        dispatch(:subscribe, subscription, frame)
      when :unsubscribe
        subscription = session.unsubscribe(frame)
        dispatch(:unsubscribe, subscription, frame)
      end

      frame.receipt unless frame.detached?
    rescue => e
      if frame.detached?
        session.error(e)
      else
        frame.error(e)
      end

      if e.is_a?(ClientError) or e.is_a?(Disconnected)
        terminate
      else
        raise e
      end
    end

    def cleanup
      @session.subscriptions.each do |subscription|
        dispatch(:unsubscribe, subscription, nil)
      end
      dispatch(:close)
    end
  end
end
