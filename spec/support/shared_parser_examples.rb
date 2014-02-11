# encoding: UTF-8
RSpec.shared_examples_for "a stompede parser" do
  let(:parser) { described_class.new }

  context "#parse" do
    def parse_all(data)
      messages = []
      parser.parse(data.force_encoding("BINARY")) { |m| messages << m }
      messages
    end

    context "command" do
      it "can parse commands" do
        messages = parse_all("CONNECT\n\n\x00")
        messages.length.should eq(1)
        messages[0].command.should eq("CONNECT")
      end
    end

    context "headers" do
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
        messages[0].headers.should eq("moo" => nil)
      end

      it "nullifies previous headers" do
        messages = parse_all("CONNECT\nmoo:\nmoo:hello\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers.should eq("moo" => nil)
      end

      it "prioritises first header when given multiple of same key" do
        messages = parse_all("CONNECT\nkey:first\nkey:second\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers.should eq("key" => "first")
      end

      it "parses multibyte headers as UTF-8" do
        messages = parse_all("MESSAGE\nwhat:üp\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers["what"].should eq "\xC3\xBCp".force_encoding("UTF-8")
        messages[0].headers["what"].encoding.should eq Encoding::UTF_8
      end

      it "parses multibyte headers as UTF-8 even if content type specifies something else" do
        messages = parse_all("MESSAGE\ncontent-type:text/plain;charset=ISO-8859-1\nwhat:üp\n\n\x00")
        messages.length.should eq(1)
        messages[0].headers["what"].should eq "\xC3\xBCp".force_encoding("UTF-8")
        messages[0].headers["what"].encoding.should eq Encoding::UTF_8
      end
    end

    context "body" do
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

      it "parses body as binary string when no content-type given" do
        messages = parse_all("MESSAGE\n\nWhat üp\x00")
        messages.length.should eq(1)
        messages[0].body.should eq "What \xC3\xBCp".force_encoding("BINARY")
        messages[0].body.encoding.should eq Encoding::BINARY
      end

      it "parses body as encoded string when content-type is a text type and charset is given" do
        messages = parse_all("MESSAGE\ncontent-type:text/plain;charset=ISO-8859-1\n\nWhat \xFCp\x00")
        messages.length.should eq(1)
        messages[0].body.should eq "What \xFCp".force_encoding("iso-8859-1")
        messages[0].body.encoding.should eq Encoding::ISO_8859_1
      end

      it "parses body as encoded string when content-type is not a text type and charset is given" do
        messages = parse_all("MESSAGE\ncontent-type:application/octet-stream;charset=ISO-8859-1\n\nWhat \xFCp\x00")
        messages.length.should eq(1)
        messages[0].body.should eq "What \xFCp".force_encoding("iso-8859-1")
        messages[0].body.encoding.should eq Encoding::ISO_8859_1
      end

      it "parses body as utf-8 encoded string when content-type is a text type and charset is not given" do
        messages = parse_all("MESSAGE\ncontent-type:text/plain\n\nWhat üp\x00")
        messages.length.should eq(1)
        messages[0].body.should eq "What \xC3\xBCp".force_encoding("UTF-8")
        messages[0].body.encoding.should eq Encoding::UTF_8
      end

      it "parses body as binary string when content-type is not a text type and charset is not given" do
        messages = parse_all("MESSAGE\ncontent-type:application/octet-stream\n\nWhat \xFCp\x00")
        messages.length.should eq(1)
        messages[0].body.should eq "What \xFCp".force_encoding("BINARY")
        messages[0].body.encoding.should eq Encoding::BINARY
      end
    end

    context "multiple messages" do
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

    context "multiple invocations" do
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

    context "fails on invalid messages" do
      specify "no block given" do
        expect { parser.parse("CONNECT\n\n\x00") }.to raise_error(LocalJumpError)
      end

      specify "invalid command" do
        expect { parser.parse("CONNET\n\n\x00") }.to raise_error(Stompede::Stomp::ParseError)
      end

      specify "unfinished command" do
        expect { parser.parse("CONNECT\x00") }.to raise_error(Stompede::Stomp::ParseError)
      end

      specify "header with colon" do
        expect { parser.parse("CONNECT\nfoo: :bar\n\n\x00") }.to raise_error(Stompede::Stomp::ParseError)
      end

      specify "header with invalid escape" do
        expect { parser.parse("CONNECT\nfoo:\\t\n\n\x00") }.to raise_error(Stompede::Stomp::ParseError)
      end

      specify "body longer than content length" do
        expect { parser.parse("CONNECT\ncontent-length:0\n\nx\x00") }.to raise_error(Stompede::Stomp::ParseError)
      end

      specify "invalid content length" do
        expect { parser.parse("CONNECT\ncontent-length:LAWL\n\nx\x00") }.to raise_error(Stompede::Stomp::Error, /invalid content length "LAWL"/)
      end

      specify "re-trying invocation after an error" do
        first_error = begin
          parser.parse("CONNET")
        rescue Stompede::Stomp::ParseError => ex
          ex
        end

        first_error.should be_a(Stompede::Stomp::ParseError)

        second_error = begin
          parser.parse("")
        rescue Stompede::Stomp::ParseError => ex
          ex
        end

        second_error.should eql(first_error)
      end

      specify "total size bigger than global max message size setting" do
        Stompede::Stomp.stub(:max_message_size => 30)
        parser = described_class.new
        parser.parse("CONNECT\n") # 8
        parser.parse("header:value\n") # 21
        expect {
          parser.parse("other:val\n") # 31
        }.to raise_error(Stompede::Stomp::MessageSizeExceeded)
      end

      specify "total size bigger than local max message size setting" do
        parser = described_class.new(max_message_size = 30)
        parser.parse("CONNECT\n") # 8
        parser.parse("header:value\n") # 21
        expect {
          parser.parse("other:val\n") # 31
        }.to raise_error(Stompede::Stomp::MessageSizeExceeded)
      end
    end
  end
end
