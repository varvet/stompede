module Stompede
  # dispatches a frame to the application, this is implemented as an actor so
  # that the `read_loop` can pipeline and continue processing messages while
  # the message is being dispatched. Otherwise we might get deadlocks.
  class Dispatcher
    include Celluloid

    def initialize
      @subscriptions ||= Hash.new { |h, k| h[k] = Set.new }
    end

    def close(session, app)
      session.subscriptions.each do |subscription|
        unsubscribe(subscription)
      end
    end

    def message_all(destination, body, headers = {})
      @subscriptions.fetch(destination, []).dup.each do |subscription|
        subscription.message(body, headers)
      end
    end

    def subscribe(subscription)
      @subscriptions[subscription.destination].add(subscription)
    end

    def unsubscribe(subscription)
      @subscriptions[subscription.destination].delete(subscription)
      @subscriptions.delete(subscription.destination) if @subscriptions[subscription.destination].empty?
    end

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
        subscribe(subscription)
        app.dispatch(:subscribe, subscription, frame)
      when :unsubscribe
        subscription = session.unsubscribe(frame)
        unsubscribe(subscription)
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
