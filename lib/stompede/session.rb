module Stompede
  class Session
    attr_accessor :connected, :disconnected, :server_heart_beats, :client_heart_beats

    def initialize(connector, options = {})
      @connector = connector
      @subscriptions = {}
      @mutex = Mutex.new
      @server_heart_beats = options[:server_heart_beats] || [0, 0]
      @client_heart_beats = options[:client_heart_beats] || [0, 0]
    end

    def subscriptions
      @mutex.synchronize { @subscriptions.values }
    end

    def write(value)
      @connector.write(self, value.to_str)
    end

    def write_and_wait_for_ack(subscription, message, timeout)
      @connector.write_and_wait_for_ack(self, subscription, message, timeout)
    rescue Celluloid::AbortError => e
      raise e.cause
    end

    def error(exception, headers = {})
      exception = exception.cause if exception.is_a?(Celluloid::AbortError)
      unless exception.is_a?(Disconnected)
        safe_write(ErrorFrame.new(exception, headers))
        close
      end
    end

    def safe_write(value)
      write(value)
    rescue Disconnected
    end

    def close
      @connector.close(self)
    end

    def subscribe(frame)
      subscription = Subscription.new(self, frame)
      @mutex.synchronize do
        if @subscriptions[subscription.id]
          raise ClientError, "subscription with id #{subscription.id.inspect} already exists"
        end
        @subscriptions[subscription.id] = subscription
      end
      subscription
    end

    def unsubscribe(frame)
      subscription = Subscription.new(self, frame)
      @mutex.synchronize do
        unless @subscriptions[subscription.id]
          raise ClientError, "subscription with id #{subscription.id.inspect} does not exist"
        end
        @subscriptions.delete(subscription.id)
      end
    end

    def inspect
      "#<Stompede::Session #{object_id}>"
    end

    def outgoing_heart_beats
      if server_heart_beats[0].zero? or client_heart_beats[1].zero?
        0
      else
        [server_heart_beats[0], client_heart_beats[1]].max
      end
    end

    def incoming_heart_beats
      if server_heart_beats[1].zero? or client_heart_beats[0].zero?
        0
      else
        [server_heart_beats[1], client_heart_beats[0]].max
      end
    end
  end
end
