``` ruby
class StompedeApp < Stompede::Base
  def initialize
    @subscribers = []
    @worker = Worker.pool(16)
    @dispatcher = CustomDispatcher.new(self)
  end

  mount "/other", MyStomplet

  open do |session|
    session.open_timeout = after(5) { session.close }
  end

  connect do |session, message|
    worker.do_heavy_work
  end

  disconnect do |session, message|
    foo = @foo
    some_other_actor.some_method
    @foo = foo + 1
  end

  close do |session|

  end

  subscribe "/foo/bar" do |subscription, message|
    if not_authenticated?
      subscription.close
    else
      reply = subscription.message("Hello")
      qqweokqwoek
      end
  end

  unsubscribe "/foo/bar" do |subscription, message|
    subscription.message("WAT?")
  end

  message "/foo/bar" do |subscriber, message|
    @subscribers.each do |subscriber|
      subscriber << message
    end
    after(0) { raise "foo" }
  end
end
```

sessions = Queue.new

app = StompedeApp.new
handler = Handler.new(app, sessions)

server = TCPServer.new

loop do
  app << server.accept
end

parser = Parser.new

parser.on_message do |message|
  app.dispatch(message)
end

loop do
  parser << session.read
end
