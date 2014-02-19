module Stompede
  class Ack
    def initialize
      @wait_for_ack = {}
      @ack_queue = {}
    end

    def wait(session, subscription, message, timeout)
      id = message["ack"]
      condition = Celluloid::Condition.new
      @wait_for_ack[id] = condition

      if subscription.ack_mode == :cumulative
        @ack_queue[subscription.id] ||= []
        @ack_queue[subscription.id] << condition
      end

      ack = condition.wait(timeout)

      if subscription.ack_mode == :cumulative
        index = @ack_queue[subscription.id].index(condition)
        if index
          @ack_queue[subscription.id].slice!(0..index).each do |condition|
            condition.signal(ack)
          end
        end
      end

      ack
    end

    def signal(session, frame)
      condition = @wait_for_ack[frame["id"]]
      condition.signal(frame) if condition
    end

    def cancel(message)
      @wait_for_ack.delete(message["ack"])
    end

    def waiting_for_ack?
      not @wait_for_ack.empty?
    end
  end
end
