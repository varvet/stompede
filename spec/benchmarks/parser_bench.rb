parser = Stompede::Stomp::Parser

message = "CONNECT\n\n\x00"
bench "Parser.parse minimal" do
  parser.parse(message)
end

message = "CONNECT\nheart-beat:0,0\n\n\x00"
bench "Parser.parse with headers" do
  parser.parse(message)
end

message = "CONNECT\n\nbody\x00"
bench "Parser.parse with small body" do
  parser.parse(message)
end

message = "CONNECT\nheart-beat:0,0\n\nbody\x00"
bench "Parser.parse with headers and small body" do
  parser.parse(message)
end
