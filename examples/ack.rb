require "stompede"
require "set"

class MyApp < Stompede::Stomplet
  def initialize(session)
    super
    @subscriptions = Set.new
  end

  def on_subscribe(subscription, frame)
    puts "on_subscribe"
    @subscriptions.add(subscription)
    reply = subscription.message("Hello")
    puts "received ack for on_unsubscribe #{reply.inspect}"
  end

  def on_unsubscribe(subscription, frame)
    @subscriptions.delete(subscription)
  end

  def on_send(frame)
    puts "on_send"
    acks = @subscriptions.map do |subscription|
      subscription.message("hello")
    end
    puts "received acks for on_send #{acks.inspect}"
  end
end

puts "listening!"
Stompede::TCPServer.new(MyApp).listen("127.0.0.1", 5000)
