parser = Stompede::Stomp::Parser

bench "Parser.parse minimal", "CONNECT\n\n\x00" do |message|
  parser.parse(message)
end

bench "Parser.parse with headers", "CONNECT\nheart-beat:0,0\n\n\x00" do |message|
  parser.parse(message)
end

bench "Parser.parse with small body", "CONNECT\n\nbody\x00" do |message|
  parser.parse(message)
end

bench "Parser.parse with headers and small body", "CONNECT\nheart-beat:0,0\n\nbody\x00" do |message|
  parser.parse(message)
end

bench "Parser.parse with invalid contents", "CONNECT" do |message|
  parser.parse(message) == nil
end
