require "stompede"

class MyApp < Stompede::Base
  def initialize
    @subscriptions = []
  end

  def on_subscribe(subscription)
    reply = subscription.message("Hello")

    @subscriptions.add(subscription)
  end

  def on_unsubscribe(subscription)
    @subscriptions.delete(subscription)
  end

  def on_send(frame)
    puts "sending message"
    ack = @subscriptions.each do |subscription|
      subscription.message("hello")
    end
    puts "sent!"
    p ack
  end
end

puts "listening!"
Stompede::TCPServer.new(MyApp).listen("127.0.0.1", 5000)
