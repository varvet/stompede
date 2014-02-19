# encoding: UTF-8

describe Stompede::Stomplet do
  integration_test!

  describe "#on_connect" do
    context "when connector accepts heart beats" do
      let(:connector) { Stompede::Connector.new(app_klass, heart_beats: [0.005, 0.005]) }

      it "sends heart-beats at regular intervals" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "0,2")
        parse_message(client_io).command.should == "CONNECTED"
        client_io.readpartial(1000).should == "\n"
        client_io.readpartial(1000).should == "\n"
      end

      it "receives heart-beats at regular intervals" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "2,0")
        parse_message(client_io).command.should == "CONNECTED"
        client_io.write("\n")
        sleep 0.003
        client_io.write("\n")
        app.should be_alive
        sleep 0.008
        client_io.should receive_error(Stompede::ClientError, "client must send heart beats at least every 5ms")
        app.should_not be_alive
      end

      it "does not send heart beats when client doesn't want to receive them" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "0,0")
        parse_message(client_io).command.should == "CONNECTED"
        sleep 0.008
        client_io.should be_an_empty_socket
      end

      it "does not receive heart beats when client doesn't want to send them" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "0,2")
        parse_message(client_io).command.should == "CONNECTED"
        sleep 0.008
        app.should be_alive
      end

      it "lets client configure when to receive heart beats" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "0,10")
        parse_message(client_io).command.should == "CONNECTED"
        sleep 0.008
        client_io.should be_an_empty_socket
        client_io.readpartial(1000).should == "\n"
      end

      it "lets client configure when to send heart-beats" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "10,0")
        parse_message(client_io).command.should == "CONNECTED"
        sleep 0.008
        app.should be_alive
        sleep 0.003
        app.should_not be_alive
      end
    end

    context "when connector requires heart beats" do
      let(:connector) { Stompede::Connector.new(app_klass, heart_beats: [0.005, 0.005], require_heart_beats: true) }

      it "sends heart-beats at regular intervals" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "5,2")
        parse_message(client_io).command.should == "CONNECTED"
        sleep 0.003
        client_io.write("\n")
        client_io.readpartial(1000).should == "\n"
        client_io.write("\n")
        client_io.readpartial(1000).should == "\n"
      end

      it "receives heart-beats at regular intervals" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "2,5")
        parse_message(client_io).command.should == "CONNECTED"
        client_io.write("\n")
        sleep 0.003
        client_io.write("\n")
        app.should be_alive
        sleep 0.008
        client_io.should receive_error(Stompede::ClientError, "client must send heart beats at least every 5ms")
        app.should_not be_alive
      end

      it "does not send heart beats when client doesn't want to receive them" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "2,0")
        parse_message(client_io).command.should == "CONNECTED"
        sleep 0.003
        client_io.write("\n")
        sleep 0.003
        client_io.should be_an_empty_socket
      end

      it "raises a client error when client doesn't want to send heart beats" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "0,0")
        client_io.should receive_error(Stompede::ClientError, "client must agree to send heart beats at least every 5ms")
      end

      it "lets client configure when to receive heart beats" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "2,10")
        parse_message(client_io).command.should == "CONNECTED"
        sleep 0.003
        client_io.write("\n")
        sleep 0.003
        client_io.should be_an_empty_socket
        client_io.write("\n")
        sleep 0.003
        client_io.write("\n")
        sleep 0.003
        client_io.readpartial(1000).should == "\n"
      end

      it "raises a client error when client doesn't want to send heart beats often enough" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "50,0")
        client_io.should receive_error(Stompede::ClientError, "client must agree to send heart beats at least every 5ms")
      end
    end
  end
end
