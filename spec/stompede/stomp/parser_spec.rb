describe Stompede::Stomp::Parser do
  let(:parser) { Stompede::Stomp::Parser }

  describe "messages" do
    it "parses a CONNECT frame" do
      parser.parse("CONNECT\n\n\x00").should be_true
    end
  end
end
