module Stompede
  # dispatches a frame to the application, this is implemented as an actor so
  # that the `read_loop` can pipeline and continue processing messages while
  # the message is being dispatched. Otherwise we might get deadlocks.
  class Dispatcher
    include Celluloid

    def dispatch(session, app, frame)
      frame.validate!

      if frame.command == :connect and not session.connected
        session.connected = true
      elsif frame.command == :connect
        raise ClientError, "must not send CONNECT or STOMP frame after connection is already open"
      elsif not session.connected
        raise ClientError, "client is not connected"
      elsif frame.command == :disconnect
        session.connected = false
      end

      case frame.command
      when :connect, :disconnect, :send
        app.dispatch(frame.command, frame)
      when :subscribe
        subscription = session.subscribe(frame)
        app.dispatch(:subscribe, subscription, frame)
      when :unsubscribe
        subscription = session.unsubscribe(frame)
        app.dispatch(:unsubscribe, subscription, frame)
      end

      frame.receipt unless frame.detached?
    rescue => e
      if frame.detached?
        session.error(e)
      else
        frame.error(e)
      end
    end
  end
end
