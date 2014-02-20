describe Stompede::Session do
  integration_test!

  describe "#message_all" do
    it "sends all messages to all subscribers" do
      client1 = connect_client
      client2 = connect_client
      client3 = connect_client

      send_message(client1, "SUBSCRIBE", id: 1, destination: "foo", receipt: "123")
      send_message(client2, "SUBSCRIBE", id: 1, destination: "foo", receipt: "123")
      send_message(client3, "SUBSCRIBE", id: 1, destination: "bar", receipt: "123")
      parse_message(client1).command.should eq("RECEIPT")
      parse_message(client2).command.should eq("RECEIPT")
      parse_message(client3).command.should eq("RECEIPT")

      connector.message_all("foo", "hello")

      parse_message(client1).body.should eq("hello")
      parse_message(client2).body.should eq("hello")
      client3.should be_an_empty_socket

      connector.message_all("bar", "world", quox: "mox")

      client1.should be_an_empty_socket
      client2.should be_an_empty_socket
      message = parse_message(client3)
      message.body.should == "world"
      message["quox"].should eq("mox")
    end
  end
end
