# encoding: UTF-8

class MooError < StandardError; end

describe Stompede::Base do
  integration_test

  describe "generic client errors" do
    it "terminates the connection on parser errors" do
      send_message(client_io, "INVALID_COMMAND", "foo" => "Bar")
      client_io.should receive_error(StompParser::ParseError, "unexpected I in chunk (\" -->I<-- NVALID_COMMAND\")")
      app_monitor.wait_for_terminate
    end
  end

  describe "#on_open" do
    it "is called when a socket is opened" do
      latch.receive(:open)
      app.should be_alive
    end
  end

  describe "#on_close" do
    it "is called when a socket is closed" do
      client_io.close
      latch.receive(:close)
      app_monitor.wait_for_terminate
    end

    it "is called even when app throws an error", error: :open do
      latch.receive(:close)
      client_io.should receive_error(MooError, "MOOOO!")
    end

    it "closes socket even when on_close dies", error: [:open, :close] do
      latch.receive(:close)
      client_io.should receive_error(MooError, "MOOOO!")
    end
  end

  describe "#on_connect" do
    it "is called when a client sends a CONNECT frame" do
      send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "foo" => "Bar")

      message = latch.receive(:connect).first
      message["foo"].should eq("Bar")
    end

    it "is called when a client sends a STOMP frame" do
      send_message(client_io, "STOMP", "accept-version" => Stompede::STOMP_VERSION, "foo" => "Bar")

      message = latch.receive(:connect).first
      message["foo"].should eq("Bar")
    end

    it "does not send a receipt, because the STOMP spec says so" do
      send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "receipt" => "1234")
      latch.receive(:connect)
      message = parse_message(client_io)
      message.command.should eq("CONNECTED")
      message["receipt-id"].should be_nil
      client_io.should be_an_empty_socket
    end

    it "replies with a CONNECTED frame when the handler succeeds" do
      send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "foo" => "Bar")
      message = parse_message(client_io)
      message.command.should eq("CONNECTED")
      message["version"].should eq("1.2")
      message["server"].should eq("Stompede/#{Stompede::VERSION}")
      message["session"].should match(/\A[a-f0-9\-]{36}\z/)
    end

    it "replies with an ERROR frame when the handler fails", error: :connect do
      send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "foo" => "Bar")
      client_io.should receive_error(MooError, "MOOOO!")
      expect { app_monitor.wait_for_crash! }.to raise_error(MooError, "MOOOO!")
    end

    it "sends a client error when client does not support STOMP version #{Stompede::STOMP_VERSION}" do
      send_message(client_io, "CONNECT", "accept-version" => "1.0,1.1")
      client_io.should receive_error(Stompede::ClientError, "client must support STOMP version #{Stompede::STOMP_VERSION}", version: Stompede::STOMP_VERSION)
      app_monitor.wait_for_terminate
    end

    it "crashes when the client sends another frame before the CONNECT frame"

    it "crashes when the client sends multiple CONNECT frames"

    context "with detached frame", detach: :connect do
      it "does not send a CONNECTED frame when the client sends a CONNECT" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION)
        latch.receive(:connect)

        client_io.should be_an_empty_socket
        app.should be_alive
      end

      it "sends a CONNECTED frame when processing is finished" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION)
        frame = latch.receive(:connect).last

        client_io.should be_an_empty_socket
        frame.receipt(foo: "bar")
        message = parse_message(client_io)
        message.command.should eq("CONNECTED")
        message["foo"].should eq("bar")
        message["receipt-id"].should be_nil
      end

      it "sends an ERROR frame and closes connection when processing fails" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION)
        frame = latch.receive(:connect).last

        client_io.should be_an_empty_socket
        frame.error(RuntimeError.new("it died"), foo: "bar")
        client_io.should receive_error(RuntimeError, "it died", "foo" => "bar")
      end
    end
  end

  shared_examples_for "a callback with receipts" do |command, callback, headers = {}|
    it "sends a receipt when the client sends a #{command} frame with a receipt header" do
      send_message(client_io, command, headers.merge("receipt" => "1234"))
      latch.receive(callback)

      message = parse_message(client_io)
      message.command.should eq("RECEIPT")
      message["receipt-id"].should eq("1234")

      app.should be_alive
      server_io.should_not be_closed
    end

    it "includes the receipt in the error when app throws an error", error: callback do
      send_message(client_io, command, headers.merge("receipt" => "1234"))
      latch.receive(callback)

      client_io.should receive_error(MooError, "MOOOO!", "receipt-id" => "1234")
    end

    context "with detached frame", detach: callback do
      it "does not send a receipt when the client sends a #{command} frame with a receipt header" do
        send_message(client_io, command, headers.merge("receipt" => "1234"))
        latch.receive(callback)

        client_io.should be_an_empty_socket
        app.should be_alive
      end

      it "does not include the receipt in the error when app throws an error", error: callback do
        send_message(client_io, command, headers.merge("receipt" => "1234"))
        latch.receive(callback)
        client_io.should receive_error(MooError, "MOOOO!", "receipt-id" => nil)
      end

      it "sends a receipt when processing is finished" do
        send_message(client_io, command, headers.merge("receipt" => "1234"))
        frame = latch.receive(callback).last

        client_io.should be_an_empty_socket
        frame.receipt(foo: "bar")
        message = parse_message(client_io)
        message.command.should eq("RECEIPT")
        message["receipt-id"].should eq("1234")
        message["foo"].should eq("bar")
      end

      it "sends an ERROR frame with receipt and closes connection when processing fails" do
        send_message(client_io, command, headers.merge("receipt" => "1234"))
        frame = latch.receive(callback).last

        client_io.should be_an_empty_socket
        frame.error(RuntimeError.new("it died"), foo: "bar")
        client_io.should receive_error(RuntimeError, "it died", "receipt-id" => "1234", "foo" => "bar")
      end
    end

    context "with detached frame and no receipt requested" do
      it "does nothing when processing is finished" do
        send_message(client_io, command, headers)
        frame = latch.receive(callback).last

        client_io.should be_an_empty_socket
        frame.receipt(foo: "bar")
        client_io.should be_an_empty_socket
      end

      it "sends a regular ERROR frame and closes connection when processing fails" do
        send_message(client_io, command, headers)
        frame = latch.receive(callback).last

        client_io.should be_an_empty_socket
        frame.error(RuntimeError.new("it died"), foo: "bar")
        client_io.should receive_error(RuntimeError, "it died", "receipt-id" => nil, "foo" => "bar")
      end
    end
  end

  describe "#on_disconnect" do
    it "is called when a client sends a DISCONNECT frame" do
      send_message(client_io, "DISCONNECT", "foo" => "Bar")

      frame = latch.receive(:disconnect).first
      frame["foo"].should eq("Bar")

      app.should be_alive
      server_io.should_not be_closed
    end

    it_behaves_like "a callback with receipts", "DISCONNECT", :disconnect

    it "is not called when a socket is closed" do
      client_io.close
      latch.invocations_until(:close).should_not include(:disconnect)
    end

    it "is not called when app throws an error", error: :open do
      latch.invocations_until(:close).should_not include(:disconnect)
      client_io.should receive_error(MooError, "MOOOO!")
    end

    it "crashes when the client sends further frames after the disconnect frame"
  end

  describe "#on_send" do
    it "is called when a client sends a SEND frame" do
      send_message(client_io, "SEND", "Hello", "destination" => "/foo/bar", "foo" => "Bar")

      frame = latch.receive(:send).first
      frame["foo"].should eq("Bar")
      frame.destination.should eq("/foo/bar")

      app.should be_alive
      server_io.should_not be_closed
    end

    it_behaves_like "a callback with receipts", "SEND", :send

    it "closes socket when it throws an error", error: :send do
      send_message(client_io, "SEND", "Hello", "destination" => "/foo/bar", "foo" => "Bar")
      client_io.should receive_error(MooError, "MOOOO!")
    end
  end

  describe "#on_subscribe" do
    it "is called when a client sends a SUBSCRIBE frame" do
      send_message(client_io, "SUBSCRIBE", "destination" => "/foo/bar", "id" => "1", "foo" => "Bar")

      subscription, frame = latch.receive(:subscribe)
      frame["foo"].should eq("Bar")
      frame.destination.should eq("/foo/bar")

      app.should be_alive
      server_io.should_not be_closed
    end

    it_behaves_like "a callback with receipts", "SUBSCRIBE", :subscribe, id: "1", destination: "/foo/bar"

    it "closes socket when it throws an error", error: :subscribe do
      send_message(client_io, "SUBSCRIBE", "destination" => "/foo/bar", "id" => "1", "foo" => "Bar")
      client_io.should receive_error(MooError, "MOOOO!")
    end

    it "replies with an error if subscription does not include a destination" do
      send_message(client_io, "SUBSCRIBE", "id" => "1")

      latch.invocations_until(:close).should eq([:open, :close])

      client_io.should receive_error(Stompede::ClientError, "subscription does not include a destination")
      app_monitor.wait_for_terminate
    end

    it "replies with an error if subscription does not include an id" do
      send_message(client_io, "SUBSCRIBE", "destination" => "1")

      latch.invocations_until(:close).should eq([:open, :close])

      client_io.should receive_error(Stompede::ClientError, "subscription does not include an id")
      app_monitor.wait_for_terminate
    end

    it "replies with an error if a subscription with the same id already exists" do
      send_message(client_io, "SUBSCRIBE", "destination" => "1", "id" => "1")
      send_message(client_io, "SUBSCRIBE", "destination" => "2", "id" => "1")

      latch.invocations_until(:close).should eq([:open, :subscribe, :unsubscribe, :close])

      client_io.should receive_error(Stompede::ClientError, "subscription with id \"1\" already exists")
      app_monitor.wait_for_terminate
    end
  end

  describe "#on_unsubscribe" do
    before do
      send_message(client_io, "SUBSCRIBE", "id" => "1", "destination" => "/foo")
    end

    it "is called when a client sends an unsubscribe frame with the previous Subscription" do
      send_message(client_io, "UNSUBSCRIBE", "id" => "1", "foo" => "Bar")

      subscribe_subscription, _ = latch.receive(:subscribe)
      unsubscribe_subscription, frame = latch.receive(:unsubscribe)

      frame["foo"].should eq("Bar")
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      app.should be_alive
      server_io.should_not be_closed
    end

    it_behaves_like "a callback with receipts", "UNSUBSCRIBE", :unsubscribe, id: "1"

    it "closes socket when it throws an error", error: :unsubscribe do
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")

      client_io.should receive_error(MooError, "MOOOO!")
    end

    it "replies with an error if subscription does not include an id" do
      send_message(client_io, "UNSUBSCRIBE")

      client_io.should receive_error(Stompede::ClientError, "subscription does not include an id")
      app_monitor.wait_for_terminate
    end

    it "replies with an error if a subscription with the same id does not exist" do
      send_message(client_io, "UNSUBSCRIBE", "id" => "2")

      client_io.should receive_error(Stompede::ClientError, "subscription with id \"2\" does not exist")
      app_monitor.wait_for_terminate
    end

    it "removes subscription when unsubscribing" do
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")
      send_message(client_io, "UNSUBSCRIBE", "id" => "1")

      client_io.should receive_error(Stompede::ClientError, "subscription with id \"1\" does not exist")
      app_monitor.wait_for_terminate
    end

    it "is called if the session has a subscription and the socket is closed" do
      subscribe_subscription, _ = latch.receive(:subscribe)
      client_io.close
      unsubscribe_subscription, frame = latch.receive(:unsubscribe)

      frame.should be_nil
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      app_monitor.wait_for_terminate
    end

    it "is called if the session has a subscription and the app dies", error: :send do
      subscribe_subscription, _ = latch.receive(:subscribe)
      send_message(client_io, "SEND")
      unsubscribe_subscription, frame = latch.receive(:unsubscribe)

      frame.should be_nil
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      client_io.should receive_error(MooError, "MOOOO!")
    end

    it "is called if subscription raises an error", error: :subscribe do
      subscribe_subscription, _ = latch.receive(:subscribe)
      unsubscribe_subscription, frame = latch.receive(:unsubscribe)

      frame.should be_nil
      unsubscribe_subscription.id.should eq("1")
      unsubscribe_subscription.should eql(subscribe_subscription)

      client_io.should receive_error(MooError, "MOOOO!")
    end
  end
end
