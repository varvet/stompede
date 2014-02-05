require "bundler/setup"
require "stompede"
require "pry"
require "timeout"

Celluloid.logger.level = Logger::ERROR

module Helpers
  def self.included(rspec)
    rspec.before do
      @_latch = Queue.new
    end
  end

  def latch
    @_latch
  end

  def await(method)
    Timeout.timeout(0.5) do
      loop do
        data = @_latch.pop
        if data[0] == method
          return data.drop(1)
        end
      end
    end
  rescue Timeout::Error
    raise "Await timed out!"
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

RSpec.configure do |config|
  config.include(Helpers)

  config.around do |ex|
    Celluloid.boot
    ex.run
    Celluloid.shutdown
  end
end
