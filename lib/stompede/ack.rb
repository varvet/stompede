module Stompede
  class Ack
    def initialize
      @wait_for_ack = {}
      @responses = {}
      @ack_queue = {}
    end

    def wait(session, subscription, message, timeout)
      id = message["ack"]
      condition = Celluloid::Condition.new
      @wait_for_ack[id] = condition

      if subscription.ack_mode == :cumulative
        @ack_queue[subscription.id] ||= []
        @ack_queue[subscription.id] << [condition, message]
      end

      Celluloid.timeout(timeout) do
        until @responses[id]
          condition.wait
        end
      end

      ack = @responses.delete(id)

      if subscription.ack_mode == :cumulative
        index = @ack_queue[subscription.id].index([condition, message])
        if index
          @ack_queue[subscription.id].slice!(0..index).each do |condition, message|
            @responses[message["ack"]] = ack
            condition.signal
          end
        end
      end

      ack
    rescue Celluloid::Task::TimeoutError
      raise Stompede::TimeoutError, "timed out waiting for ACK"
    end

    def signal(session, frame)
      @responses[frame["id"]] = frame
      condition = @wait_for_ack[frame["id"]]
      condition.signal if condition
    end

    def cancel(message)
      @wait_for_ack.delete(message["ack"])
    end

    def waiting_for_ack?
      not @wait_for_ack.empty?
    end
  end
end
