# Stompede

[![Build Status](https://travis-ci.org/stompede/stompede.png?branch=master)](https://travis-ci.org/stompede/stompede)
[![Code Climate](https://codeclimate.com/github/stompede/stompede.png)](https://codeclimate.com/github/stompede/stompede)

Stompede is a [STOMP](http://stomp.github.io/) server written in Ruby, built on
[Celluloid](http://celluloid.io/).

With STOMP, clients can subscribe to multiple destinations and send and receive
messages. STOMP is a transport agnostic protocol, and Stompede comes with a TCP
server as well as a WebSocket server. The WebSocket server enables browsers to
subscribe to multiple destinations over a single WebSocket connection, greatly
reducing the number of open socket connections.

### Usage

Stompede apps are written by inheriting from `Stompede::Stomplet`:

``` ruby
class MyStomplet < Stompede::Stomplet
  def on_open
  end

  def on_connect(frame)
  end

  def on_subscribe(subscription, frame)
  end

  def on_send(frame)
  end

  def on_unsubscribe(subscription, frame)
  end

  def on_disconnect(frame)
  end

  def on_close
  end
end
```

It can then be served up via:

``` ruby
Stompede::TCPServer.new(MyStomplet).listen("127.0.0.1", 8675)
```

In this case `MyStomplet` is a `Celluloid::Actor`, and Stompede will create one
instance of this actor for each active socket connection.

The above example illustrates all available callbacks.

`on_open` and `on_close` are always called when the socket is opened and
when it is closed. These callbacks are dependable, and you can rely on
Stompede always calling them, no matter what.

`on_connect` and `on_disconnect` are called when the client sends the `CONNECT`
and `DISCONNECT` frames respectively. Misbehaving clients may not do so. Also
network errors or sudden closing of the socket may cause even well behaved
clients not to call these handlers. Especially, do not rely on the
`on_disconnect` handler to clean up any resources allocated for the client, use
`on_close` instead. They are still useful in that clients may provide headers
with the frames, for example for authentication.

`on_subscribe` receives a subscription object, on which `message` may be called,
in order to send message to the client. For example:

``` ruby
class MyStomplet < Stompede::Stomplet
  def on_subscribe(subscription, frame)
    @pinger = every(1) do
      subscription.message("PONG", pong: "yes")
    end
  end

  def on_unsubscribe(subscription, frame)
    @pinger.cancel
  end
end
```

This example also shows how you can use Celluloid timers. Stompede supports the
`heart-beat` header in the STOMP protocol, so this kind of pinging is probably
not necessary.

Stompede guarantees that `on_unsubscribe` will always be called even in the
event of the socket suddently closing for any reason.

The STOMP protocol requires that a client must have subscribed before the
server can send messages to the client, and that messages must be tied to a
subscription, this is why it is not possible to send messages to a client
without a valid subscription.

### Heartbeats

Heartbeats allow you to make sure that idle clients are promptly disconnected.
If you want your server to send or receive heartbeats, specify them like this:

``` ruby
Stompede::TCPServer.new(MyStomplet, heart_beats: [20, 50])
```

The first number specifies how often the client should send heart beats and the
second number specifies how often the server sends heart beats. Both values are
in seconds (note that the STOMP spec uses milliseconds).

The STOMP spec allows the client to override the heartbeat setting, and essentially
opt out of having to send heart beats. This works fine if you trust your clients,
but if clients are untrusted, you might want to force them to send hearbeats. Stompede
has a special option for this:

``` ruby
Stompede::TCPServer.new(MyStomplet, heart_beats: [20, 50], require_heart_beats: true)
```

### Connect timeout

Compliant clients should send a `CONNECT` or `STOMP` frame shortly after
opening a socket connection. This allows you to do authentication, and to set
up heart beats. Malicious might open a lot of socket connections, but never
actually send a `CONNECT` frame. By default, Stompede closes the connection if
the client has not sent a `CONNECT` frame within 10 seconds. If you want to
change this timeout, you can use the `connect_timeout` config option:

``` ruby
Stompede::TCPServer.new(MyStomplet, connect_timeout: 120)
```

Set it to `nil` to disable the connect timeout entirely.

### Receipts

The STOMP protocol allows clients to request receipts when sending messages to
the server. They do this by specifying the `receipt` header in the frame
they're sending. The Server then responds with a `RECEIPT` frame when the
request has finished processing.

Stompede automatically sends receipts when the client asks for them. In the
case that the callback handler returns without raising any errors, a receipt
will be sent, if the handler raises an error, an `ERROR` frame is sent instead,
and the connection is closed.

There may be situations where you want more granular control over when a
receipt is sent. For example, you might want to perform some processing
asynchronously:

``` ruby
class MyStomplet < Stompede::Stomplet
  class Worker
    include Celluloid

    def do_work(frame)
      # ... do heavy work
      frame.receipt
    rescue => e
      frame.error(e)
      raise
    end
  end

  def initialize
    @worker = Worker.new_link
  end

  def on_send(frame)
    frame.detach! # don't send an automatic receipt
    @worker.async.do_work(frame)
  end
end
```

The call to `frame.detach!` tells Stompede not to automatically send a receipt.
You then need to manually send a receipt by calling `frame.receipt` or
`frame.error`. These methods are thread-safe, so you can call them from
another actor.

### The ack-mode header, ACK and NACK

### The subscription registry

### Handling global state

### Transactions

Transactions are unfortunately not yet supported, pull requests welcome!

### Development

Development should be ez.

``` bash
git clone git@github.com:stompede/stompede.git # git, http://git-scm.com/
cd stompede
bundle install # Bundler, http://bundler.io/
rake
```

### Contributing

1. Fork it on GitHub (<http://github.com/stompede/stompede/fork>).
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Follow the [Development](#development) instructions in this README.
4. Create your changes, please add tests.
5. Commit your changes (`git commit -am 'Add some feature'`).
6. Push to the branch (`git push origin my-new-feature`).
7. Create new pull request on GitHub.

### License

[MIT](MIT-LICENSE.txt)
