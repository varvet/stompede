module Stompede
  class Stomplet < LightStomplet
    include Celluloid

    finalizer :cleanup

    def dispatch(*)
      super
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
