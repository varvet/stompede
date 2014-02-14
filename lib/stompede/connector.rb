module Stompede
  class Connector
    # dispatches a frame to the application, this is implemented as an actor so
    # that the `read_loop` can pipeline and continue processing messages while
    # the message is being dispatched. Otherwise we might get deadlocks.
    class Dispatcher
      include Celluloid

      def dispatch(session, app, frame)
        app.raw_dispatch(frame)
      rescue => e
        session.error(e)
      end
    end

    BUFFER_SIZE = 1024 * 16

    include Celluloid::IO
    include Celluloid::Logger

    def initialize(app_klass)
      @dispatcher = Dispatcher.new_link
      @sockets = {}
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
            if stompede_frame.command == :ack
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

    def wait_for_ack(message, timeout)
      condition = Condition.new
      @wait_for_ack[message["ack"]] = condition
      condition.wait(timeout)
    rescue => e
      abort e
    ensure
      @wait_for_ack.delete(message["ack"])
    end

    def close(session)
      socket = @sockets.delete(session)
      socket.close if socket
    rescue IOError => e
    end
  end
end
