describe Stompede::Subscription do
  integration_test

  before do
    send_message(client_io, "SUBSCRIBE", "id" => "1234", "destination" => "/foo", "ack" => example.metadata[:ack])
  end

  let!(:subscription) { latch.receive(:subscribe).first }

  describe "#message" do
    it "sends a message to the client" do
      subscription.message("What üp?", "foo" => "Bar")

      message = parse_message(client_io)
      message.command.should eq("MESSAGE")
      message.destination.should eq("/foo")
      message["subscription"].should eq("1234")
      message["message-id"].should match(/\A[a-f0-9\-]{36}\z/)
      message.content_length.should eq(9)
    end

    context "with ack mode not set" do
      it "does nothing if the client is no longer connected" do
        client_io.close
        subscription.message("What üp?", "foo" => "Bar")
      end
    end

    context "with ack mode set to 'auto'", ack: "auto" do
      it "does nothing if the client is no longer connected" do
        client_io.close
        subscription.message("What üp?", "foo" => "Bar")
      end
    end

    context "with ack mode set to 'client-individual'", ack: "client-individual" do
      it "blocks until the client sends an ACK frame" do
        future = Celluloid::Future.new { subscription.message("What üp?", "foo" => "Bar") }

        message = parse_message(client_io)
        future.should_not be_ready
        send_message(client_io, "ACK\nid:#{message["ack"]}\nfoo:bar\n\n\0")

        ack_frame = future.value
        ack_frame.command.should eq(:ack)
        ack_frame["foo"].should eq("bar")
      end

      it "times out" do
        expect do
          subscription.message("What üp?", "foo" => "Bar", timeout: 0.01)
        end.to raise_error(Celluloid::ConditionError)
        connector.should_not be_waiting_for_ack
      end

      it "does not acknowledge previous frames" do
        future_one = Celluloid::Future.new { subscription.message("Hey", "foo" => "Bar") }
        future_two = Celluloid::Future.new { subscription.message("Ho", "foo" => "Bar") }

        message_one = parse_message(client_io)
        message_two = parse_message(client_io)

        send_message(client_io, "ACK\nid:#{message_two["ack"]}\nfoo:bar\n\n\0")

        future_two.value["id"].should eq(message_two["ack"])
        future_one.should_not be_ready
      end

      it "blocks until the clients sends a NACK frame" do
        future = Celluloid::Future.new { subscription.message("What üp?", "foo" => "Bar") }

        message = parse_message(client_io)
        future.should_not be_ready
        send_message(client_io, "NACK\nid:#{message["ack"]}\nfoo:bar\n\n\0")

        ack_frame = future.value
        ack_frame.command.should eq(:nack)
        ack_frame["foo"].should eq("bar")
      end

      it "raises an error if the client has disconnected" do
        client_io.close
        expect do
          subscription.message("What üp?", "foo" => "Bar")
        end.to raise_error(Stompede::Disconnected)
      end
    end

    context "with ack mode set to 'client'", ack: "client" do
      it "blocks until the client sends an ACK frame"
      it "acknowledges previous frames"
      it "does not acknowledge frames sent to another subscription"
      it "blocks until the clients sends a NACK frame"
      it "raises an error if the client has disconnected"
    end
  end

  describe "#message!" do
    context "with ack mode set to 'auto'", ack: "auto" do
      it "does nothing if the client is no longer connected"
    end

    context "with ack mode set to 'client-individual'", ack: "client-individual" do
      it "blocks until the client sends an ACK frame"
      it "does not acknowledge previous frames"
      it "raises an error if the client sends a NACK frame"
      it "raises an error if the client has disconnected"
    end

    context "with ack mode set to 'client'", ack: "client" do
      it "blocks until the client sends an ACK frame"
      it "acknowledges previous frames"
      it "does not acknowledge frames sent to another subscription"
      it "raises an error if the client sends a NACK frame"
      it "raises an error if the client has disconnected"
    end
  end
end
