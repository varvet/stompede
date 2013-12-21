describe Stompede::Stomp::Parser do
  let(:parser) { Stompede::Stomp::Parser }

  describe "parsing command" do
    it "can parse commands" do
      message = parser.parse("CONNECT\n\n\x00")
      message.command.should eq("CONNECT")
    end
  end

  describe "parsing headers" do
    it "can parse simple headers" do
      message = parser.parse("CONNECT\nmoo:cow\n\n\x00")
      message.headers.should eq("moo" => "cow")
    end

    it "can parse multiple headers" do
      message = parser.parse("CONNECT\nmoo:cow\nbaah:sheep\n\n\x00")
      message.headers.should eq("moo" => "cow", "baah" => "sheep")
    end

    it "can parse headers with NULLs in them" do
      message = parser.parse("CONNECT\nnull\x00:null\x00\n\n\x00")
      message.headers.should eq("null\x00" => "null\x00")
    end

    it "can parse headers with escape characters" do
      message = parser.parse("CONNECT\nnull\\c:\\r\\n\\c\\\\\n\n\x00")
      message.headers.should eq("null:" => "\r\n:\\")
    end

    it "can parse headers with no value" do
      message = parser.parse("CONNECT\nmoo:\n\n\x00")
      message.headers.should eq("moo" => "")
    end

    it "prioritises first header when given multiple of same key" do
      message = parser.parse("CONNECT\nkey:first\nkey:second\n\n\x00")
      message.headers.should eq("key" => "first")
    end
  end

  describe "parsing body" do
    it "can parse body"
    it "can parse binary body"
  end

  describe "fails on invalid messages" do
    specify "unfinished command" do
      parser.parse("CONNECT\x00").should be_nil
    end

    specify "no end of headers" do
      parser.parse("CONNECT\n\x00").should be_nil
    end

    specify "header with colon" do
      parser.parse("CONNECT\nfoo: :bar\n\n\x00").should be_nil
    end

    specify "header with invalid escape" do
      parser.parse("CONNECT\nfoo:\\t\n\n\x00").should be_nil
    end
  end
end
