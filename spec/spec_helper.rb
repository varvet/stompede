require "bundler/setup"
require "stompede"
require "pry"

Celluloid.logger.level = Logger::ERROR

module Helpers
  def parse_message(io)
    parser = Stompede::Stomp::Parser.new
    parser.parse(io.readpartial(Stompede::BUFFER_SIZE)) do |message|
      return message
    end
  end
end

RSpec.configure do |config|
  config.include(Helpers)
end
