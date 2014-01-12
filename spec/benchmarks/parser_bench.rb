$parser = Stompede::Stomp::Parser.new

def parse_one(message)
  $parser.parse(message) { |m| return m }
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

bench "Parser.parse with invalid contents", "CONNECT" do |message|
  parse_one(message) == nil
end
