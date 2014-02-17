module Stompede
  class Connector
    # dispatches a frame to the application, this is implemented as an actor so
    # that the `read_loop` can pipeline and continue processing messages while
    # the message is being dispatched. Otherwise we might get deadlocks.
    class Dispatcher
      include Celluloid

      def dispatch(session, app, frame)
        frame.validate!

        if frame.command == :connect and not session.connected
          session.connected = true
        elsif frame.command == :connect
          raise ClientError, "must not send CONNECT or STOMP frame after connection is already open"
        elsif not session.connected
          raise ClientError, "first frame must be a CONNECT or STOMP frame"
        end

        case frame.command
        when :connect, :disconnect, :send
          app.dispatch(frame.command, frame)
        when :subscribe
          subscription = session.subscribe(frame)
          app.dispatch(:subscribe, subscription, frame)
        when :unsubscribe
          subscription = session.unsubscribe(frame)
          app.dispatch(:unsubscribe, subscription, frame)
        end

        frame.receipt unless frame.detached?
      rescue => e
        if frame.detached?
          session.error(e)
        else
          frame.error(e)
        end
      end
    end

    BUFFER_SIZE = 1024 * 16

    include Celluloid::IO
    include Celluloid::Logger

    def initialize(app_klass)
      @dispatcher = Dispatcher.new_link
      @sockets = {}
      @ack_queue = {}
      @app_klass = app_klass
      @wait_for_ack = {}
    end

    def connect(socket)
      session = Session.new(Actor.current)
      @sockets[session] = socket
      read_loop(socket, session)
    ensure
      close(session)
    end

    def read_loop(socket, session)
      parser = StompParser::Parser.new

      begin
        app = @app_klass.new(session)
        app.dispatch(:open)
      rescue => e
        session.error(e)
        return
      end

      loop do
        chunk = begin
          socket.readpartial(BUFFER_SIZE)
        rescue IOError => e
          return
        end

        begin
          parser.parse(chunk) do |frame|
            stompede_frame = Frame.new(session, frame.command, frame.headers, frame.body)
            if stompede_frame.command == :ack or stompede_frame.command == :nack
              respond_to_ack(stompede_frame)
            else
              @dispatcher.async.dispatch(session, app, stompede_frame)
            end
          end
        rescue => e
          session.error(e)
          return
        end
      end
    ensure
      begin
        app.terminate
      rescue Celluloid::DeadActorError
      end
    end

    def write(session, data)
      socket = @sockets[session]
      if socket
        socket.write(data.to_str)
      else
        abort Disconnected.new("client disconnected")
      end
    rescue IOError => e
      abort Disconnected.new(e.message)
    end

    def respond_to_ack(frame)
      condition = @wait_for_ack[frame["id"]]
      condition.signal(frame) if condition
    end

    def write_and_wait_for_ack(session, subscription, message, timeout)
      id = message["ack"]
      condition = Condition.new
      @wait_for_ack[id] = condition
      if subscription.ack_mode == :cumulative
        @ack_queue[subscription.id] ||= []
        @ack_queue[subscription.id] << condition
      end
      # FIXME: there's a race condition in that if `write` pipelines, we might
      # receive a signal on the Condition before we've called `wait.
      write(session, message)
      ack = condition.wait(timeout)
      if subscription.ack_mode == :cumulative
        index = @ack_queue[subscription.id].index(condition)
        if index
          @ack_queue[subscription.id].slice!(0..index).each do |condition|
            condition.signal(ack)
          end
        end
      end
      ack
    rescue => e
      abort e
    ensure
      @wait_for_ack.delete(id)
    end

    # mostly useful for tests
    def waiting_for_ack?
      not @wait_for_ack.empty?
    end

    def close(session)
      socket = @sockets.delete(session)
      socket.close if socket
    rescue IOError => e
    end
  end
end
