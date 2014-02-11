require "bundler/setup"
require "stompede"
require "pry"
require "timeout"

require "support/test_app"
require "support/crash_monitor"
require "support/helpers"

io = File.open(File.expand_path("./spec.log", File.dirname(__FILE__)), "w")
Celluloid.logger = Logger.new(io)
Celluloid.logger.level = Logger::ERROR

RSpec.configure do |config|
  config.include(Helpers)

  config.around do |ex|
    Celluloid.boot
    ex.run
    Celluloid.shutdown
  end
end
