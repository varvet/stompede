describe Stompede::Subscription do
  integration_test!
  connect!

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

    it "raises an error if the client has disconnected" do
      client_io.close
      expect do
        subscription.message("What üp?", "foo" => "Bar")
      end.to raise_error(Stompede::Disconnected)
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

      it "acknowledges previous frames" do
        future_one = Celluloid::Future.new { subscription.message("Hey", "foo" => "Bar") }
        future_two = Celluloid::Future.new { subscription.message("Ho", "foo" => "Bar") }

        message_one = parse_message(client_io)
        message_two = parse_message(client_io)

        send_message(client_io, "ACK\nid:#{message_two["ack"]}\nfoo:bar\n\n\0")

        future_one.value["id"].should eq(message_two["ack"])
        future_two.value["id"].should eq(message_two["ack"])
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
  end

  describe "#message!" do
    it "sends a message to the client" do
      subscription.message!("What üp?", "foo" => "Bar")

      message = parse_message(client_io)
      message.command.should eq("MESSAGE")
      message.destination.should eq("/foo")
      message["subscription"].should eq("1234")
      message["message-id"].should match(/\A[a-f0-9\-]{36}\z/)
      message.content_length.should eq(9)
    end

    it "raises an error if the client has disconnected" do
      client_io.close
      expect do
        subscription.message!("What üp?", "foo" => "Bar")
      end.to raise_error(Stompede::Disconnected)
    end

    context "with ack mode set to 'auto'", ack: "auto" do
      it "raises an error if the client has disconnected" do
        client_io.close
        expect do
          subscription.message!("What üp?", "foo" => "Bar")
        end.to raise_error(Stompede::Disconnected)
      end
    end

    context "with ack mode set to 'client-individual'", ack: "client-individual" do
      it "raises an error if the client sends a NACK frame" do
        future = Celluloid::Future.new { subscription.message!("What üp?", "foo" => "Bar") }

        message = parse_message(client_io)
        future.should_not be_ready
        send_message(client_io, "NACK\nid:#{message["ack"]}\nfoo:bar\n\n\0")

        expect { future.value }.to raise_error(Stompede::Nack)
      end
    end

    context "with ack mode set to 'client'", ack: "client" do
      it "raises an error if the client sends a NACK frame" do
        future = Celluloid::Future.new { subscription.message!("What üp?", "foo" => "Bar") }

        message = parse_message(client_io)
        future.should_not be_ready
        send_message(client_io, "NACK\nid:#{message["ack"]}\nfoo:bar\n\n\0")

        expect { future.value }.to raise_error(Stompede::Nack)
      end
    end
  end
end
