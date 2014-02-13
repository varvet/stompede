module Stompede
  class Connector
    BUFFER_SIZE = 1024 * 16

    include Celluloid::IO
    include Celluloid::Logger

    def initialize(app_klass)
      @sockets = {}
      @app_klass = app_klass
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
            app.raw_dispatch(stompede_frame)
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

    def close(session)
      socket = @sockets.delete(session)
      socket.close if socket
    rescue IOError => e
    end
  end
end
