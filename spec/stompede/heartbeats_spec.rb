# encoding: UTF-8

describe Stompede::Stomplet do
  integration_test!

  describe "#on_connect" do
    context "when connector accepts heart beats" do
      let(:connector) { Stompede::Connector.new(app_klass, heart_beats: [0.005, 0.005]) }

      it "sends heart-beats at regular intervals" do
        send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION, "heart-beat" => "2,2")
        parse_message(client_io).command.should == "CONNECTED"
        client_io.readpartial(1000).should == "\n"
        client_io.readpartial(1000).should == "\n"
      end

      it "receives heart-beats at regular intervals"
      it "does not send heart beats when client doesn't want to receive them"
      it "does not receive heart beats when client doesn't want to send them"
      it "lets client configure when to receive heart beats"
      it "lets client configure when to send heart-beats"
    end

    context "when connector requires heart beats" do
      let(:connector) { Stompede::Connector.new(app_klass, heart_beats: [0.005, 0.005], require_heart_beats: true, ack_modes: [:auto]) }

      it "sends heart-beats at regular intervals"
      it "receives heart-beats at regular intervals"
      it "does not send heart beats when client doesn't want to receive them"
      it "raises a client error when client doesn't want to send heart beats"
      it "lets client configure when to receive heart beats"
      it "raises a client error when client doesn't want to send heart beats often enough"
    end
  end
end
