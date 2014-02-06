module Helpers
  class Latch
    def initialize
      @queue = Queue.new
    end

    def push(object)
      @queue.push(object)
    end

    def invocations_until(method)
      messages_until(method).map(&:first)
    end

    def receive(method)
      messages_until(method).last.drop(1)
    end

  private

    def messages_until(method)
      Timeout.timeout(0.5) do
        list = []
        loop do
          list.push(@queue.pop)
          break if list.last[0] == method
        end
        list
      end
    rescue Timeout::Error
      raise "Latch timed out!"
    end
  end

  def self.included(rspec)
    rspec.before do
      @_latch = Latch.new
    end
  end

  def latch
    @_latch
  end

  def parse_message(io)
    parser = Stompede::Stomp::Parser.new
    Timeout.timeout(0.5) do
      parser.parse(io.readpartial(Stompede::BUFFER_SIZE)) do |message|
        return message
      end
    end
  rescue Timeout::Error
    raise "Parsing message timed out!"
  end
end

