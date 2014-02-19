module Stompede
  class Connector
    BUFFER_SIZE = 1024 * 16
    DEFAULT_CONNECT_TIMEOUT = 10

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

    def connect_timeout
      @options.fetch(:connect_timeout, DEFAULT_CONNECT_TIMEOUT)
    end

    def read_loop(session)
      parser = StompParser::Parser.new
      heart_beat_timer = nil

      begin
        app = @app_klass.new(session)
        app.dispatch(:open)
        if connect_timeout
          connect_timer = after(connect_timeout) do
            session.error(ClientError.new("must send a CONNECT or STOMP frame within #{(connect_timeout * 1000).round}ms"))
          end
        end
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
              connect_timer.cancel if connect_timer
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
      yield
      @ack.wait(message, timeout)
    rescue => e
      abort e
    end
    execute_block_on_receiver :wait_for_ack

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
