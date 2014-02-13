module Stompede
  class Frame
    attr_reader :session, :command, :headers, :body

    def initialize(session, command, headers, body)
      @session = session
      @command = command.downcase.to_sym
      @command = :connect if @command == :stomp
      @headers = headers
      @body = body
      @detached = false
    end

    def to_str
      StompParser::Frame.new(command.to_s.upcase, headers, body).to_str
    end
    alias_method :to_s, :to_str

    def [](key)
      headers[key]
    end

    def destination
      headers["destination"]
    end

    def detach!
      @detached = true
    end

    def detached?
      @detached
    end

    def receipt!(receipt_headers = {})
      if command == :connect
        receipt_headers["version"] = STOMP_VERSION
        receipt_headers["server"] = "Stompede/#{Stompede::VERSION}"
        receipt_headers["session"] = SecureRandom.uuid
        session.write(StompParser::Frame.new("CONNECTED", receipt_headers, ""))
      elsif headers["receipt"]
        receipt_headers["receipt-id"] = headers["receipt"]
        session.write(StompParser::Frame.new("RECEIPT", receipt_headers, ""))
      end
    end

    def error!(error, error_headers = {})
      if headers["receipt"] and not command == :connect
        error_headers["receipt-id"] = headers["receipt"]
      end
      session.error(error, error_headers)
    end

    def validate!
      if command == :subscribe
        raise ClientError, "subscription does not include a destination" unless headers["destination"]
      end
      if command == :subscribe or command == :unsubscribe
        raise ClientError, "subscription does not include an id" unless headers["id"]
      end
      if command == :connect
        unless headers["accept-version"].split(",").include?(STOMP_VERSION)
          error = ClientError.new("client must support STOMP version #{STOMP_VERSION}")
          error!(error, version: STOMP_VERSION)
          raise error
        end
      end
    end
  end
end
