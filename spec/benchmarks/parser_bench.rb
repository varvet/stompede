require_relative "../bench_helper"

def parse_one(data)
  message = nil
  parser = Stompede::Stomp::Parser.new
  parser.parse(data) { |m| message = m }
  message
end

def parse_one_invalid(data)
  begin
    parse_one(data)
  rescue Stompede::ParseError
    true
  else
    false
  end
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

bench "Parser.parse with invalid command", "CONNET\n\n\x00" do |message|
  parse_one_invalid(message)
end

bench "Parser.parse with invalid header contents", "CONNECT\nheart::beat\n\x00" do |message|
  parse_one_invalid(message)
end

bench "Parser.parse with stray null after message", "CONNECT\n\n\x00\x00" do |message|
  parse_one_invalid(message)
end
