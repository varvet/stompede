class TestApp < Stompede::Base
  def initialize(latch)
    @latch = latch
  end

  def on_open(session)
    @latch.push [:on_open, session]
  end

  def on_close(session)
    @latch.push [:on_close, session]
  end

  def on_connect(session, message)
    @latch.push [:on_connect, session, message]
  end
end

describe Stompede::Base do
  let(:app) { TestApp.new(latch) }
  let(:sockets) { UNIXSocket.pair.map { |s| Celluloid::IO::UNIXSocket.new(s) } }
  let(:client_io) { sockets[0] }
  let(:server_io) { sockets[1] }

  describe "#on_open" do
    it "is called when a socket is opened" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      session = await(:on_open).first
      session.should be_an_instance_of(Stompede::Session)
    end
  end

  describe "#on_close" do
    it "is called when a socket is closed" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      client_io.close

      session = await(:on_close).first
      session.should be_an_instance_of(Stompede::Session)
    end
  end

  describe "#on_connect" do
    it "is called when a client sends a CONNECT frame" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      client_io.write(Stompede::Stomp::Message.new("CONNECT", { "foo" => "Bar" }, "").to_str)

      session, message = await(:on_connect)
      session.should be_an_instance_of(Stompede::Session)
      message["foo"].should eq("Bar")
    end

    it "replies with a CONNECTED frame when the handler succeeds" do
      connector = Stompede::Connector.new(app)
      connector.async.open(server_io)

      client_io.write(Stompede::Stomp::Message.new("CONNECT", { "foo" => "Bar" }, "").to_str)
      message = parse_message(client_io)
      message.command.should eq("CONNECTED")
      message["version"].should eq("1.2")
      message["server"].should eq("Stompede/#{Stompede::VERSION}")
      message["session"].should match(/\A[a-f0-9\-]{36}\z/)
    end
  end
end
