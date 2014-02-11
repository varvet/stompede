# encoding: UTF-8

describe Stompede::Base do
  # There is no TCPSocket.pair :(
  let(:sockets) do
    server = TCPServer.new("127.0.0.1", 0)
    client = Thread.new { TCPSocket.new("127.0.0.1", server.addr[1]) }
    [server.accept, client.value]
  end

  let(:client_io) { sockets[0] }
  let(:server_io) { Celluloid::IO::TCPSocket.new(sockets[1]) }

  let(:app_monitor) { CrashMonitor.new }
  let!(:app) do
    TestApp.new(server_io, latch, error: example.metadata[:error]) do |app|
      app_monitor.observe(app)
    end
  end

  describe "#on_open" do
    it "is called when a socket is opened" do
      latch.receive(:on_open)
      app.should be_alive
    end
  end

  describe "#on_close" do
    it "is called when a socket is closed" do
      client_io.close
      latch.receive(:on_close)
      app_monitor.wait_for_terminate
    end

    it "is called even when app throws an error", error: :on_open do
      latch.receive(:on_close)
      client_io.should receive_error(TestApp::MooError, "MOOOO!")
    end

    it "closes socket even when on_close dies", error: [:on_open, :on_close] do
      latch.receive(:on_close)
      client_io.should receive_error(TestApp::MooError, "MOOOO!")
    end
  end

  describe "#on_connect" do
    it "is called when a client sends a CONNECT frame" do
      send_message(client_io, "CONNECT", "foo" => "Bar")

      message = latch.receive(:on_connect).first
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
      expect { app_monitor.wait_for_crash! }.to raise_error(TestApp::MooError, "MOOOO!")
    end
  end

  describe "#on_disconnect" do
    it "is called when a client sends a DISCONNECT frame" do
      send_message(client_io, "DISCONNECT", "foo" => "Bar")

      frame = latch.receive(:on_disconnect).first
      frame["foo"].should eq("Bar")

      app.should be_alive
      server_io.should_not be_closed
    end

    it "is not called when a socket is closed" do
      client_io.close

      latch.invocations_until(:on_close).should_not include(:on_disconnect)
    end

    it "is not called when app throws an error", error: :on_open do
      latch.invocations_until(:on_close).should_not include(:on_disconnect)
      client_io.should receive_error(TestApp::MooError, "MOOOO!")
    end
  end

  describe "#on_send" do
    it "is called when a client sends a SEND frame" do
      send_message(client_io, "SEND", "Hello", "destination" => "/foo/bar", "foo" => "Bar")

      frame = latch.receive(:on_send).first
      frame["foo"].should eq("Bar")
      frame.destination.should eq("/foo/bar")

      app.should be_alive
      server_io.should_not be_closed
    end

    it "closes socket when it throws an error", error: :on_send do
      send_message(client_io, "SEND", "Hello", "destination" => "/foo/bar", "foo" => "Bar")
      client_io.should receive_error(TestApp::MooError, "MOOOO!")
    end
  end

  describe "#on_subscribe" do
    it "is called when a client sends a SUBSCRIBE frame" do
      send_message(client_io, "SUBSCRIBE", "destination" => "/foo/bar", "id" => "1", "foo" => "Bar")

      subscription, frame = latch.receive(:on_subscribe)
      frame["foo"].should eq("Bar")
      frame.destination.should eq("/foo/bar")

      app.should be_alive
      server_io.should_not be_closed
    end

    it "closes socket when it throws an error", error: :on_subscribe do
      send_message(client_io, "SUBSCRIBE", "destination" => "/foo/bar", "id" => "1", "foo" => "Bar")
      client_io.should receive_error(TestApp::MooError, "MOOOO!")
    end

    it "replies with an error if subscription does not include a destination" do
      send_message(client_io, "SUBSCRIBE", "id" => "1")

      latch.invocations_until(:on_close).should eq([:on_open, :on_close])

      client_io.should receive_error(Stompede::ClientError, "subscription does not include a destination")
      app_monitor.wait_for_terminate
    end

    it "replies with an error if subscription does not include an id" do
      send_message(client_io, "SUBSCRIBE", "destination" => "1")

      latch.invocations_until(:on_close).should eq([:on_open, :on_close])

      client_io.should receive_error(Stompede::ClientError, "subscription does not include an id")
      app_monitor.wait_for_terminate
    end

    it "replies with an error if a subscription with the same id already exists" do
      send_message(client_io, "SUBSCRIBE", "destination" => "1", "id" => "1")
      send_message(client_io, "SUBSCRIBE", "destination" => "2", "id" => "1")

      latch.invocations_until(:on_close).should eq([:on_open, :on_subscribe, :on_unsubscribe, :on_close])

      client_io.should receive_error(Stompede::ClientError, "subscription with id \"1\" already exists")
      app_monitor.wait_for_terminate
    end
  end

  describe "#on_unsubscribe" do
    it "is called when a client sends an unsubscribe frame with the previous Subscription" do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")
      send_message(client_io, "UNSUBSCRIBE", "id" => "1", "foo" => "Bar")

      subscribe_subscription, _ = latch.receive(:on_subscribe)
      unsubscribe_subscription, frame = latch.receive(:on_unsubscribe)

      frame["foo"].should eq("Bar")
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      app.should be_alive
      server_io.should_not be_closed
    end

    it "closes socket when it throws an error", error: :on_unsubscribe do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")

      client_io.should receive_error(TestApp::MooError, "MOOOO!")
    end

    it "replies with an error if subscription does not include an id" do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")
      send_message(client_io, "UNSUBSCRIBE")

      client_io.should receive_error(Stompede::ClientError, "subscription does not include an id")
      app_monitor.wait_for_terminate
    end

    it "replies with an error if a subscription with the same id does not exist" do
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")

      client_io.should receive_error(Stompede::ClientError, "subscription with id \"1\" does not exist")
      app_monitor.wait_for_terminate
    end

    it "removes subscription when unsubscribing" do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")

      client_io.should receive_error(Stompede::ClientError, "subscription with id \"1\" does not exist")
      app_monitor.wait_for_terminate
    end

    it "is called if the session has a subscription and the socket is closed" do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")

      subscribe_subscription, _ = latch.receive(:on_subscribe)
      client_io.close
      unsubscribe_subscription, frame = latch.receive(:on_unsubscribe)

      frame.should be_nil
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      app_monitor.wait_for_terminate
    end

    it "is called if the session has a subscription and the app dies", error: :on_send do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")

      subscribe_subscription, _ = latch.receive(:on_subscribe)
      send_message(client_io, "SEND")
      unsubscribe_subscription, frame = latch.receive(:on_unsubscribe)

      frame.should be_nil
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      client_io.should receive_error(TestApp::MooError, "MOOOO!")
    end

    it "is called if subscription raises an error", error: :on_subscribe do
      send_message(client_io, "SUBSCRIBE", "destination" => "/foo/bar", "id" => "1", "foo" => "Bar")

      subscribe_subscription, _ = latch.receive(:on_subscribe)
      unsubscribe_subscription, frame = latch.receive(:on_unsubscribe)

      frame.should be_nil
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      client_io.should receive_error(TestApp::MooError, "MOOOO!")
    end
  end

  describe Stompede::Subscription do
    describe "#message" do
      it "sends a message to the client" do
        send_message(client_io, "SUBSCRIBE", "id" => "1234", "destination" => "/foo")
        subscription = latch.receive(:on_subscribe).first
        subscription.message("What üp?", "foo" => "Bar")

        message = parse_message(client_io)
        message.command.should eq("MESSAGE")
        message.destination.should eq("/foo")
        message["subscription"].should eq("1234")
        message["message-id"].should match(/\A[a-f0-9\-]{36}\z/)
        message.content_length.should eq(9)
      end

      it "does nothing if the client is no longer connected"
    end
  end
end
