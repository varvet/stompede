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
        messages = parse_all("CONNECT\n")
        messages.should be_empty

        messages = parse_all("\n\x00")
        messages.length.should eq(1)
        messages[0].command.should eq "CONNECT"
      end

      it "parses messages split across buffer markings" do
        messages = parse_all("\n\nCONN")
        messages.should be_empty

        messages = parse_all("ECT\n\n\x00")
        messages.length.should eq(1)
        messages[0].command.should eq "CONNECT"
      end

      it "parses messages split across header keys" do
        messages = parse_all("CONNECT\nheader:")
        messages.should be_empty

        messages = parse_all("value\n\n\x00")
        messages.length.should eq(1)
        messages[0].command.should eq "CONNECT"
        messages[0].headers.should eq("header" => "value")
      end

      it "parses binary message split across body" do
        messages = parse_all("CONNECT\ncontent-length:4\n\n\x00a")
        messages.should be_empty

        messages = parse_all("b\x00\x00")
        messages.length.should eq(1)
        messages[0].command.should eq "CONNECT"
        messages[0].body.should eq("\x00ab\x00")
      end

      it "parses messages split across messages" do
        messages = parse_all("CONNECT\n")
        messages.should be_empty

        messages = parse_all("\n\x00CONNEC")
        messages.length.should eq(1)
        messages[0].command.should eq "CONNECT"

        messages = parse_all("T\n\n\x00")
        messages.length.should eq(1)
        messages[0].command.should eq "CONNECT"
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

      it "can parse binary body" do
        messages = parse_all("CONNECT\ncontent-length:5\n\nbo\x00dy\x00")
        messages.length.should eq(1)
        messages[0].body.should eq "bo\x00dy"
      end
    end

    describe "failing on invalid messages" do
      specify "invalid command" do
        expect { parser.parse("CONNET\n\n\x00") }.to raise_error(Stompede::ParseError)
      end

      specify "unfinished command" do
        expect { parser.parse("CONNECT\x00") }.to raise_error(Stompede::ParseError)
      end

      specify "header with colon" do
        expect { parser.parse("CONNECT\nfoo: :bar\n\n\x00") }.to raise_error(Stompede::ParseError)
      end

      specify "header with invalid escape" do
        expect { parser.parse("CONNECT\nfoo:\\t\n\n\x00") }.to raise_error(Stompede::ParseError)
      end

      specify "message longer than content length" do
        expect { parser.parse("CONNECT\ncontent-length:0\n\nx\x00") }.to raise_error(Stompede::ParseError)
      end

      specify "failing after re-trying invocation after an error" do
        first_error = begin
          parser.parse("CONNET")
        rescue Stompede::ParseError => ex
          ex
        end

        first_error.should be_a(Stompede::ParseError)

        second_error = begin
          parser.parse("")
        rescue Stompede::ParseError => ex
          ex
        end

        second_error.should eql(first_error)
      end
    end

    describe "failing on messages exceeding allowed size" do
      let(:parser) {  }

      specify "message containing a too large command" do
        parser = Stompede::Stomp::Parser.new(4)
        expect { parser.parse("CONNECT\n\n\x00") }.to raise_error(Stompede::BufferLimitExceeded)
      end

      specify "message containing a too large header key" do
        parser = Stompede::Stomp::Parser.new(10)
        parser.parse("CONNECT\n")
        expect { parser.parse("very-long-header:value\n\n\x00") }.to raise_error(Stompede::BufferLimitExceeded)
      end

      specify "message containing a too large header value" do
        parser = Stompede::Stomp::Parser.new(10)
        parser.parse("CONNECT\n")
        expect { parser.parse("key:very-long-header\n\n\x00") }.to raise_error(Stompede::BufferLimitExceeded)
      end

      specify "message containing a too large body" do
        parser = Stompede::Stomp::Parser.new(10)
        parser.parse("CONNECT\n\n")
        expect { parser.parse("a very long body\x00") }.to raise_error(Stompede::BufferLimitExceeded)
      end

      specify "message total size too large", pending: "total size limit" do
        parser = Stompede::Stomp::Parser.new(30, 30)
        parser.parse("CONNECT\n") # 8
        parser.parse("header:value\n") # 21
        expect { parser.parse("other:val\n") }.to raise_error(Stompede::MessageSizeExceeded)
      end
    end
  end
end
