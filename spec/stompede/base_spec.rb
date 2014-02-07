describe Stompede::Base do
  let(:app) { TestApp.new(latch) }
  let(:sockets) { UNIXSocket.pair }
  let(:client_io) { sockets[0] }
  let(:server_io) { Celluloid::IO::UNIXSocket.new(sockets[1]) }
  let(:connector) { Stompede::Connector.new(TestApp.new(latch, error: example.metadata[:error])) }
  let!(:connector_monitor) { CrashMonitor.new(connector) }

  before do
    connector.async.open(server_io)
  end

  describe "#on_open" do
    it "is called when a socket is opened" do
      session = latch.receive(:on_open).first
      session.should be_an_instance_of(Stompede::Session)
    end
  end

  describe "#on_close" do
    it "is called when a socket is closed" do
      client_io.close

      session = latch.receive(:on_close).first
      session.should be_an_instance_of(Stompede::Session)
      connector.should be_alive
    end

    it "is called even when app throws an error", error: :on_open do
      session = latch.receive(:on_close).first
      session.should be_an_instance_of(Stompede::Session)

      expect { connector_monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end

    it "closes socket even when on_close dies", error: [:on_open, :on_close] do
      session = latch.receive(:on_close).first
      session.should be_an_instance_of(Stompede::Session)

      expect { connector_monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end
  end

  describe "#on_connect" do
    it "is called when a client sends a CONNECT frame" do
      send_message(client_io, "CONNECT", "foo" => "Bar")

      session, message = latch.receive(:on_connect)
      session.should be_an_instance_of(Stompede::Session)
      message["foo"].should eq("Bar")
    end

    it "replies with a CONNECTED frame when the handler succeeds" do
      send_message(client_io, "CONNECT", "foo" => "Bar")
      message = parse_message(client_io)
      message.command.should eq("CONNECTED")
      message["version"].should eq("1.2")
      message["server"].should eq("Stompede/#{Stompede::VERSION}")
      message["session"].should match(/\A[a-f0-9\-]{36}\z/)
    end

    it "replies with an ERROR frame when the handler fails", error: :on_connect do
      send_message(client_io, "CONNECT", "foo" => "Bar")
      client_io.should receive_error(TestApp::MooError, "MOOOO!")
      expect { connector_monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
    end
  end

  describe "#on_disconnect" do
    it "is called when a client sends a DISCONNECT frame" do
      send_message(client_io, "DISCONNECT", "foo" => "Bar")

      session, frame = latch.receive(:on_disconnect)
      session.should be_an_instance_of(Stompede::Session)
      frame["foo"].should eq("Bar")

      connector.should be_alive
      server_io.should_not be_closed
    end

    it "is not called when a socket is closed" do
      client_io.close

      latch.invocations_until(:on_close).should_not include(:on_disconnect)
      connector.should be_alive
    end

    it "is not called when app throws an error", error: :on_open do
      latch.invocations_until(:on_close).should_not include(:on_disconnect)

      expect { connector_monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end
  end

  describe "#on_send" do
    it "is called when a client sends a SEND frame" do
      send_message(client_io, "SEND", "Hello", "destination" => "/foo/bar", "foo" => "Bar")

      session, frame = latch.receive(:on_send)
      session.should be_an_instance_of(Stompede::Session)
      frame["foo"].should eq("Bar")
      frame.destination.should eq("/foo/bar")

      connector.should be_alive
      server_io.should_not be_closed
    end

    it "closes socket when it throws an error", error: :on_send do
      send_message(client_io, "SEND", "Hello", "destination" => "/foo/bar", "foo" => "Bar")

      expect { connector_monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end
  end

  describe "#on_subscribe" do
    it "is called when a client sends a SUBSCRIBE frame" do
      send_message(client_io, "SUBSCRIBE", "destination" => "/foo/bar", "id" => "1", "foo" => "Bar")

      session, subscription, frame = latch.receive(:on_subscribe)
      session.should be_an_instance_of(Stompede::Session)
      frame["foo"].should eq("Bar")
      frame.destination.should eq("/foo/bar")

      connector.should be_alive
      server_io.should_not be_closed
    end

    it "closes socket when it throws an error", error: :on_subscribe do
      send_message(client_io, "SUBSCRIBE", "destination" => "/foo/bar", "id" => "1", "foo" => "Bar")

      expect { connector_monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end

    it "replies with an error if subscription does not include a destination" do
      send_message(client_io, "SUBSCRIBE", "id" => "1")

      latch.invocations_until(:on_close).should eq([:on_open, :on_close])

      client_io.should receive_error(Stompede::ClientError, "subscription does not include a destination")
      connector.should be_alive
    end

    it "replies with an error if subscription does not include an id" do
      send_message(client_io, "SUBSCRIBE", "destination" => "1")

      latch.invocations_until(:on_close).should eq([:on_open, :on_close])

      client_io.should receive_error(Stompede::ClientError, "subscription does not include an id")
      connector.should be_alive
    end

    it "replies with an error if a subscription with the same id already exists" do
      send_message(client_io, "SUBSCRIBE", "destination" => "1", "id" => "1")
      send_message(client_io, "SUBSCRIBE", "destination" => "2", "id" => "1")

      latch.invocations_until(:on_close).should eq([:on_open, :on_subscribe, :on_unsubscribe, :on_close])

      client_io.should receive_error(Stompede::ClientError, "subscription with id \"1\" already exists")
      connector.should be_alive
    end
  end

  describe "#on_unsubscribe" do
    it "is called when a client sends an unsubscribe frame with the previous Subscription" do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")
      send_message(client_io, "UNSUBSCRIBE", "id" => "1", "foo" => "Bar")

      subscribe_subscription = latch.receive(:on_subscribe)[1]
      session, unsubscribe_subscription, frame = latch.receive(:on_unsubscribe)

      session.should be_an_instance_of(Stompede::Session)
      frame["foo"].should eq("Bar")
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      connector.should be_alive
      server_io.should_not be_closed
    end

    it "closes socket when it throws an error", error: :on_unsubscribe do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")

      expect { connector_monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end

    it "replies with an error if subscription does not include an id" do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")
      send_message(client_io, "UNSUBSCRIBE")

      client_io.should receive_error(Stompede::ClientError, "subscription does not include an id")
      connector.should be_alive
    end

    it "replies with an error if a subscription with the same id does not exist" do
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")

      client_io.should receive_error(Stompede::ClientError, "subscription with id \"1\" does not exist")
      connector.should be_alive
    end

    it "removes subscription when unsubscribing" do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")

      client_io.should receive_error(Stompede::ClientError, "subscription with id \"1\" does not exist")
      connector.should be_alive
    end

    it "is called if the session has a subscription and the socket is closed" do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")

      subscribe_subscription = latch.receive(:on_subscribe)[1]
      client_io.close
      session, unsubscribe_subscription, frame = latch.receive(:on_unsubscribe)

      session.should be_an_instance_of(Stompede::Session)
      frame.should be_nil
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      connector.should be_alive
    end

    it "is called if the session has a subscription and the app dies", error: :on_send do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")

      subscribe_subscription = latch.receive(:on_subscribe)[1]
      send_message(client_io, "SEND")
      session, unsubscribe_subscription, frame = latch.receive(:on_unsubscribe)

      session.should be_an_instance_of(Stompede::Session)
      frame.should be_nil
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      expect { connector_monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
      client_io.should be_eof
    end
  end
end
