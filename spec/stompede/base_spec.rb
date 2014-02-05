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
end
