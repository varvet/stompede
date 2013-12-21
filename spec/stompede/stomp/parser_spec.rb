describe Stompede::Stomp do
  let(:parser) { Stompede::Stomp }

  describe "messages" do
    it "parses a CONNECT frame" do
      message = parser.parse("CONNECT\n\n\x00")
      message.command.should eq "CONNECT"
    end
  end
end
