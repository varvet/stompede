# Stompede

[![Build Status](https://travis-ci.org/Burgestrand/stompede.png?branch=master)](https://travis-ci.org/Burgestrand/stompede)
[![Dependency Status](https://gemnasium.com/Burgestrand/stompede.png)](https://gemnasium.com/Burgestrand/stompede)
[![Code Climate](https://codeclimate.com/github/Burgestrand/stompede.png)](https://codeclimate.com/github/Burgestrand/stompede)
[![Gem Version](https://badge.fury.io/rb/stompede.png)](http://badge.fury.io/rb/stompede)

Stompede is a [STOMP](http://stomp.github.io/) server written in Ruby, built on
[Celluloid](http://celluloid.io/).

With STOMP, clients can subscribe to multiple destinations and send and receive
messages. STOMP is a transport agnostic protocol, and Stompede comes with a TCP
server as well as a WebSocket server. The WebSocket server enables browsers to
subscribe to multiple destinations over a single WebSocket connection, greatly
reducing the number of open socket connections.

## Usage

Stompede apps are written by inheriting from `Stompede::Base`:

``` ruby
class MyApp < Stompede::Base
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
Stompede::TCPServer.new(MyApp).listen("127.0.0.1", 8675)
```

In this case `MyApp` is a `Celluloid::Actor`, and Stompede will create one
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
class MyApp < Stompede::Base
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

## Heartbeats

## Disconnecting invalid or malicious clients

## Receipts

## The ack-mode header, ACK and NACK

## Transactions

Transactions are unfortunately not yet supported, pull requests welcome!

## Development

Development should be ez.

``` bash
git clone git@github.com:stompede/stompede.git # git, http://git-scm.com/
cd stompede
bundle install # Bundler, http://bundler.io/
rake
```

## Contributing

1. Fork it on GitHub (<http://github.com/Burgestrand/stompede/fork>).
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Follow the [Development](#development) instructions in this README.
4. Create your changes, please add tests.
5. Commit your changes (`git commit -am 'Add some feature'`).
6. Push to the branch (`git push origin my-new-feature`).
7. Create new pull request on GitHub.

## License

[MIT](MIT-LICENSE.txt)
