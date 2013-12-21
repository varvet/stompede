describe Stompede::Stomp do
  let(:parser) { Stompede::Stomp }

  describe "messages" do
    it "parses a CONNECT frame" do
      message = parser.parse("CONNECT\n\n\x00")
      message.command.should eq "CONNECT"
    end

    it "returns nothing if the message is not well-formed" do
      parser.parse("CONNECT").should be_nil
      parser.parse("CONNECT\n\n").should be_nil
    end
  end
end
