require_relative "../bench_helper"

def parse_one(parser, data)
  message = nil
  parser.parse(data) { |m| message = m }
  message
end

%w[CParser JavaParser RubyParser].each do |parser|
  parser = begin
    Stompede::Stomp.const_get(parser)
  rescue NameError
    next
  end

  describe "#{parser}: minimal" do |bench|
    bench.setup do
      @parser = parser.new
      @message = "CONNECT\n\n\x00"
    end

    bench.code { parse_one(@parser, @message) }
  end

  describe "#{parser}: headers and small body" do |bench|
    bench.setup do
      @parser = parser.new
      @message = "CONNECT\ncontent-length:4\n\nbody\x00"
    end

    bench.code { parse_one(@parser, @message) }
  end

  describe "#{parser}: headers and large body" do |bench|
    bench.setup do
      @parser = parser.new
      large_body = ("b" * (Stompede::Stomp.max_message_size - 50)) # make room for headers
      @message = "CONNECT\ncontent-length:#{large_body.bytesize}\n\n#{large_body}\x00"
    end

    bench.code { parse_one(@parser, @message) }
  end
end
