require_relative "../bench_helper"

describe "Message#to_str minimal" do |bench|
  bench.setup do
    @message = Stompede::Stomp::Message.new("CONNECT", nil)
  end

  bench.code { @message.to_str }

  bench.assert do |message_str|
    message_str == "CONNECT\ncontent-length:0\n\n\x00"
  end
end

describe "Message#to_str with header" do |bench|
  bench.setup do
    @message = Stompede::Stomp::Message.new("CONNECT", { "heart-beat" => "0,0" }, nil)
  end

  bench.code { @message.to_str }

  bench.assert do |message_str|
    message_str == "CONNECT\nheart-beat:0,0\ncontent-length:0\n\n\x00"
  end
end

describe "Message#to_str with headers and small body" do |bench|
  bench.setup do
    @message = Stompede::Stomp::Message.new("CONNECT", { "some" => "header" }, "body")
  end

  bench.code { @message.to_str }

  bench.assert do |message_str|
    message_str == "CONNECT\nsome:header\ncontent-length:4\n\nbody\x00"
  end
end

describe "Message#to_str with headers and large body" do |bench|
  bench.setup do
    large_binary = "b\x00" * 2 # make room for headers
    @message = Stompede::Stomp::Message.new("CONNECT", { "some" => "header" }, large_binary)
  end

  bench.code { @message.to_str }

  bench.assert do |message_str|
    message_str == "CONNECT\nsome:header\ncontent-length:#{@message.body.bytesize}\n\n#{@message.body}\x00"
  end
end
