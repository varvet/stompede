require_relative "../bench_helper"

def parse_one(data)
  message = nil
  parser = Stompede::Stomp::Parser.new
  parser.parse(data) { |m| message = m }
  message
end

bench "Parser.parse minimal", "CONNECT\n\n\x00" do |message|
  parse_one(message)
end

bench "Parser.parse with headers", "CONNECT\nheart-beat:0,0\n\n\x00" do |message|
  parse_one(message)
end

bench "Parser.parse with small body", "CONNECT\n\nbody\x00" do |message|
  parse_one(message)
end

bench "Parser.parse with headers and small body", "CONNECT\nheart-beat:0,0\n\nbody\x00" do |message|
  parse_one(message)
end
