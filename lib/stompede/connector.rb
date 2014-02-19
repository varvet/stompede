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
          raise ClientError, "client is not connected"
        elsif frame.command == :disconnect
          session.connected = false
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

    def initialize(app_klass, options = {})
      @dispatcher = Dispatcher.new_link
      @sockets = {}
      @app_klass = app_klass
      @options = options
      @ack = Ack.new(Actor.current)
    end

    def connect(socket)
      session = Session.new(Actor.current, server_heart_beats: @options[:heart_beats])
      @sockets[session] = socket
      read_loop(session)
    ensure
      close(session)
    end

    def read_loop(session)
      parser = StompParser::Parser.new
      heart_beat_timer = nil

      begin
        app = @app_klass.new(session)
        app.dispatch(:open)
      rescue => e
        session.error(e)
        return
      end

      loop do
        begin
          chunk = read(session)
          parser.parse(chunk) do |frame|
            stompede_frame = Frame.new(session, frame.command, frame.headers, frame.body)
            if stompede_frame.command == :connect
              session.client_heart_beats = stompede_frame.heart_beats
              if @options[:require_heart_beats] and (session.incoming_heart_beats.zero? or session.incoming_heart_beats > session.server_heart_beats[1])
                raise ClientError, "client must agree to send heart beats at least every #{(session.server_heart_beats[1] * 1000).round}ms"
              end
              unless session.outgoing_heart_beats.zero?
                heart_beat_timer = every(session.outgoing_heart_beats) { write(session, "\n") }
              end
            end
            if stompede_frame.command == :ack or stompede_frame.command == :nack
              @ack.signal(stompede_frame)
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
      heart_beat_timer.cancel if heart_beat_timer
      begin
        app.terminate
      rescue Celluloid::DeadActorError
      end
    end

    def read(session)
      socket = @sockets[session]
      if socket
        if session.incoming_heart_beats.zero?
          socket.readpartial(BUFFER_SIZE)
        else
          timeout(session.incoming_heart_beats) do
            socket.readpartial(BUFFER_SIZE)
          end
        end
      else
        abort Disconnected.new("client disconnected")
      end
    rescue Task::TimeoutError => e
      abort ClientError.new("client must send heart beats at least every #{(session.server_heart_beats[1] * 1000).round}ms")
    rescue IOError => e
      abort Disconnected.new(e.message)
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

    def wait_for_ack(message, timeout)
      @ack.expect(message)
      write(message.session, message)
      @ack.wait(message, timeout)
    rescue => e
      abort e
    end

    # mostly useful for tests
    def waiting_for_ack?
      @ack.waiting_for_ack?
    end

    def close(session)
      socket = @sockets.delete(session)
      socket.close if socket
    rescue IOError => e
    end
  end
end
