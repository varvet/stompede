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

  subscribe "/foo/bar" do |subscriber, message|
    @subscribers << subscriber
  end

  message "/foo/bar" do |subscriber, message|
    @subscribers.each do |subscriber|
      subscriber << message
    end
  end
end
```
