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

bench "Parser.parse with headers", "CONNECT\ncontent-length:0\n\n\x00" do |message|
  parse_one(message)
end

bench "Parser.parse with small body", "CONNECT\n\nbody\x00" do |message|
  parse_one(message)
end

bench "Parser.parse with headers and small body", "CONNECT\ncontent-length:4\n\nbody\x00" do |message|
  parse_one(message)
end

large_body = "b" * (Stompede::Stomp.max_message_size - 50) # make room for headers
bench "Parser.parse with large body", "CONNECT\n\n#{large_body}\x00" do |message|
  parse_one(message)
end

bench "Parser.parse with headers and large body", "CONNECT\ncontent-length:#{large_body.bytesize}\n\n#{large_body}\x00" do |message|
  parse_one(message)
end
