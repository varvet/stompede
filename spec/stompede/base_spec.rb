class TestApp < Stompede::Base
  def dispatch(message, session)
    session.send("Hi!")
  end
end

describe Stompede::Base do
  it "works" do
    client_side, server_side = UNIXSocket.pair.map { |s| Celluloid::IO::UNIXSocket.new(s) }

    app = TestApp.new

    app.connect(server_side)

    client_side.write(Stompede::Stomp::Message.new("SEND", {}, "Hi!").to_str)

    message = parse_message(client_side)
    message.body.should eq("Hi!")
  end
end
