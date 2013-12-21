describe Stompede::Stomp do
  let(:parser) { Stompede::Stomp }

  describe "parsing command" do
    it "can parse commands" do
      message = parser.parse("CONNECT\n\n\x00")
      message.command.should eq("CONNECT")
    end
  end

  describe "parsing headers" do
    it "can parse headers", pending: true do
      message = parser.parse("CONNECT\nmoo: cow\nnu\x00ll:a\x00b\n\x00")
      message.headers.should eq({
        "moo" => "cow",
        "baah" => ":sheep:",
        "nu\x00ll" => "a\x00b",
      })
    end
  end

  describe "parsing body" do
    it " body"
    it "parses binary body"
  end

  describe "invalid messages" do
    specify "unfinished command" do
      parser.parse("CONNECT\x00").should be_nil
    end

    specify "no end of headers" do
      parser.parse("CONNECT\n\x00").should be_nil
    end

    specify "header with colon", pending: true do
      parser.parse("CONNECT\nfoo: :bar\n\x00").should be_nil
    end
  end
end
