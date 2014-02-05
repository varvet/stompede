``` ruby
class StompedeApp < Stompede::Base
  def initialize
    @subscribers = []
    @worker = Worker.pool(16)
  end

  mount "/other", MyStomplet

  open do |connection|
    connection.open_timeout = after(5) { connection.close }
  end

  connect do |connection, message|
    worker.do_heavy_work
  end

  disconnect do |connection, message|
    foo = @foo
    some_other_actor.some_method
    @foo = foo + 1
  end

  close do |connection|

  end

  subscribe "/foo/bar" do |client, message|
    @subscribers << subscriber
  end

  unsubscribe "/foo/bar" do |client, message|
    @subscribers.delete subscriber
  end

  message "/foo/bar" do |subscriber, message|
    @subscribers.each do |subscriber|
      subscriber << message
    end
    after(0) { raise "foo" }
  end
end
```

connections = Queue.new

app = StompedeApp.new
handler = Handler.new(app, connections)

server = TCPServer.new

loop do
  app << server.accept
end

parser = Parser.new

parser.on_message do |message|
  app.dispatch(message)
end

loop do
  parser << connection.read
end
