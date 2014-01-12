describe Stompede::Stomp::Parser do
  let(:parser) { Stompede::Stomp::Parser.new }

  context "#parse" do
    def parse_all(data)
      messages = []
      parser.parse(data) do |m|
        messages << m
      end
      messages
    end

    describe "multiple invocations" do
      it "parses simple split up messages" do
        message = nil
        parser.parse("CONNECT\n") { |m| message = m }
        message.should be_nil
        parser.parse("\n\x00") { |m| message = m }
        message.should_not be_nil
        message.command.should eq "CONNECT"
      end
    end

    describe "parsing multiple messages" do
      it "yields multiple messages in a single invocation" do
        messages = parse_all("CONNECT\n\n\x00CONNECT\n\n\x00CONNECT\n\n\x00")
        messages.length.should eq(3)
        messages.map(&:command).should eq %w[CONNECT CONNECT CONNECT]
        messages.uniq.length.should eq(3)
      end

      it "allows newlines between messages" do
        messages = parse_all("\n\r\n\nCONNECT\n\n\x00\n\n\r\nCONNECT\n\n\x00\n\n")
        messages.length.should eq(2)
        messages.map(&:command).should eq %w[CONNECT CONNECT]
        messages.uniq.length.should eq(2)
      end
    end

    describe "parsing command" do
      it "can parse commands" do
        messages = parse_all("CONNECT\n\n\x00")
        messages.length.should eq(1)
        messages[0].command.should eq("CONNECT")
      end
    end

    describe "parsing headers" do
      it "can parse simple headers" do
        messages = parse_all("CONNECT\nmoo:cow\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers.should eq("moo" => "cow")
      end

      it "can parse multiple headers" do
        messages = parse_all("CONNECT\nmoo:cow\nbaah:sheep\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers.should eq("moo" => "cow", "baah" => "sheep")
      end

      it "can parse headers with NULLs in them" do
        messages = parse_all("CONNECT\nnull\x00:null\x00\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers.should eq("null\x00" => "null\x00")
      end

      it "can parse headers with escape characters" do
        messages = parse_all("CONNECT\nnull\\c:\\r\\n\\c\\\\\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers.should eq("null:" => "\r\n:\\")
      end

      it "can parse headers with no value" do
        messages = parse_all("CONNECT\nmoo:\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers.should eq("moo" => "")
      end

      it "prioritises first header when given multiple of same key" do
        messages = parse_all("CONNECT\nkey:first\nkey:second\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers.should eq("key" => "first")
      end
    end

    describe "parsing body" do
      it "can parse body" do
        messages = parse_all("CONNECT\n\nbody\x00")
        messages.length.should eq(1)
        messages[0].body.should eq "body"
      end

      it "can parse binary body", pending: "fixed length messages" do
        messages = parse_all("CONNECT\ncontent-length:1\n\n\x00\x00")
        messages.length.should eq(1)
        messages[0].body.should eq "body"
      end
    end

    describe "failing on invalid messages" do
      specify "invalid command" do
        parse_all("CONNET\n\n\x00").should be_empty
      end

      specify "unfinished command" do
        parse_all("CONNECT\x00").should be_empty
      end

      specify "no end of headers" do
        parse_all("CONNECT\n\x00").should be_empty
      end

      specify "header with colon" do
        parse_all("CONNECT\nfoo: :bar\n\n\x00").should be_empty
      end

      specify "header with invalid escape" do
        parse_all("CONNECT\nfoo:\\t\n\n\x00").should be_empty
      end

      specify "message longer than content length", pending: "fixed length messages" do
        parse_all("CONNECT\ncontent-length:0\n\nx\x00").should be_empty
      end

      specify "message shorter than content-length", pending: "fixed length messages" do
        parse_all("CONNECT\ncontent-length:2\n\nx\x00").should be_empty
      end
    end

    describe "failing on messages exceeding allowed size" do
      specify "message containing a too large command"
      specify "message containing a too large header key"
      specify "message containing a too large header value"
      specify "message containing a too large body"
      specify "message total size too large"
    end
  end
end
