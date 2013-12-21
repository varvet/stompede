message = "CONNECT\nheart-beat:0,0\n\n\x00"
parser = Stompede::Stomp::Parser

bench "Parser.parse" do
  parser.parse(message)
end
