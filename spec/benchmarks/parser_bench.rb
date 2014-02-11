require_relative "../bench_helper"

def parse_one(parser, data)
  message = nil
  parser.parse(data) { |m| message = m }
  message
end

describe "Parser.parse minimal" do |bench|
  bench.setup do
    @parser = Stompede::Stomp::Parser.new
    @message = "CONNECT\n\n\x00"
  end

  bench.code { parse_one(@parser, @message) }
end

describe "Parser.parse minimal with header" do |bench|
  bench.setup do
    @parser = Stompede::Stomp::Parser.new
    @message = "CONNECT\ncontent-length:0\n\n\x00"
  end

  bench.code { parse_one(@parser, @message) }
end

describe "Parser.parse with headers and small body" do |bench|
  bench.setup do
    @parser = Stompede::Stomp::Parser.new
    @message = "CONNECT\ncontent-length:4\n\nbody\x00"
  end

  bench.code { parse_one(@parser, @message) }
end

describe "Parser.parse with headers and large body" do |bench|
  bench.setup do
    @parser = Stompede::Stomp::Parser.new
    large_body = ("b" * (Stompede::Stomp.max_message_size - 50)) # make room for headers
    @message = "CONNECT\ncontent-length:#{large_body.bytesize}\n\n#{large_body}\x00"
  end

  bench.code { parse_one(@parser, @message) }
end
