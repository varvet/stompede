require "bundler/setup"
require "stompede"
require "perftools"

parser = Stompede::Stomp::Parser.new
body_size = (1024 * 99) / 2
large_binary = "b\x00" * body_size # make room for headers
data = <<-MESSAGE
CONNECT
content-length:#{large_binary.bytesize}

#{large_binary}\x00
MESSAGE
stream = data + data + data + data

profile_output = File.expand_path("./profile/parser.profile", File.dirname(__FILE__))
PerfTools::CpuProfiler.start(profile_output) do
  i = 100
  loop do
    parser.parse(data) do |message|
      # no op
    end

    i -= 1
    break if i <= 0
  end
end
