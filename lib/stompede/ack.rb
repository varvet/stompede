module Stompede
  class Ack
    def initialize(connector)
      @connector = connector
      @responses = {}
      @waiters = Hash.new { |h, k| h[k] = {} }
    end

    def expect(message_frame)
      condition = Celluloid::Condition.new
      subscription_id = message_frame.subscription.id
      @waiters[subscription_id][message_frame.ack_id] = condition
    end

    def wait(message_frame, timeout)
      subscription_id = message_frame.subscription.id

      Celluloid.timeout(timeout) do
        until @responses[message_frame.ack_id]
          @waiters[subscription_id][message_frame.ack_id].wait
        end
      end

      @responses.delete(message_frame.ack_id)
    rescue Celluloid::Task::TimeoutError
      raise Stompede::TimeoutError, "timed out waiting for ACK"
    ensure
      @waiters[subscription_id].delete(message_frame.ack_id)
      @waiters.delete(subscription_id) if @waiters[subscription_id].empty?
      @responses.delete(message_frame.ack_id)
    end

    def signal(ack_frame)
      subscription_id = ack_frame.ack_id.split(";").first

      return unless @waiters[subscription_id].has_key?(ack_frame.ack_id)

      signals = []

      subscription = ack_frame.session.subscriptions.find { |s| s.id == subscription_id }
      condition = @waiters[subscription_id][ack_frame.ack_id]

      @responses[ack_frame.ack_id] = ack_frame

      if subscription.ack_mode == :cumulative
        @waiters[subscription_id].each do |id, other|
          break if other == condition
          signals << [id, other]
        end
      end
      signals << [ack_frame.ack_id, condition]

      signals.each do |id, condition|
        @responses[id] = ack_frame
        condition.signal
      end
    end

    def waiting_for_ack?
      @waiters.any?
    end
  end
end
