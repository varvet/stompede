class MooError < StandardError; end

module IntegrationSetup
  module InstanceMethods
    # There is no TCPSocket.pair :(
    def create_socket_pair
      server = TCPServer.new("127.0.0.1", 0)
      client = Thread.new { TCPSocket.new("127.0.0.1", server.addr[1]) }
      [Celluloid::IO::TCPSocket.new(server.accept), client.value]
    end

    def connect_client
      server, client = create_socket_pair
      connector.async.connect(server)
      send_message(client, "CONNECT", "accept-version" => Stompede::STOMP_VERSION)
      parse_message(client).command.should eq("CONNECTED")
      client
    end
  end

  def integration_test!
    instance_eval do
      include InstanceMethods
      attr_accessor :app

      let(:sockets) { create_socket_pair }
      let(:server_io) { sockets[0] }
      let(:client_io) { sockets[1] }

      let(:app_monitor) { CrashMonitor.new }
      let(:app_klass) do
        spec = self

        Class.new(Stompede::Stomplet) do
          define_method(:initialize) do |session|
            @session = session
            @error = Array(spec.example.metadata[:error])
            @detach = Array(spec.example.metadata[:detach])
            spec.app_monitor.observe(Celluloid::Actor.current)
            spec.app = Celluloid::Actor.current
            spec.latch.push([:initialize])
          end

          define_method(:dispatch) do |command, *args|
            args.last.detach! if @detach.include?(command)
            spec.latch.push([command, *args])
            raise MooError, "MOOOO!" if @error.include?(command)
          end
        end
      end

      let(:connector) { Stompede::Connector.new(app_klass) }

      before do
        connector.async.connect(server_io)
        latch.receive(:initialize)
      end

      after do
        connector.should be_alive
      end
    end
  end

  def connect!
    before do
      send_message(client_io, "CONNECT", "accept-version" => Stompede::STOMP_VERSION)
      parse_message(client_io).command.should eq("CONNECTED")
    end
  end
end
