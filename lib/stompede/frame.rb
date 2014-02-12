module Stompede
  class Frame
    attr_reader :session, :command, :headers, :body

    def initialize(session, command, headers, body)
      @session = session
      @command = command
      @headers = headers
      @body = body
      @detached = false
    end

    def to_str
      StompParser::Frame.new(command, headers, body).to_str
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
      if connect?
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
      body = "#{error.class}: #{error.message}\n\n#{Array(error.backtrace).join("\n")}"
      error_headers["content-type"] = "text/plain"
      if headers["receipt"] and not connect?
        error_headers["receipt-id"] = headers["receipt"]
      end
      session.safe_write(StompParser::Frame.new("ERROR", error_headers, body).to_str)
      session.close
    end

    def validate!
      if command == "SUBSCRIBE"
        raise ClientError, "subscription does not include a destination" unless headers["destination"]
      end
      if command == "SUBSCRIBE" or command == "UNSUBSCRIBE"
        raise ClientError, "subscription does not include an id" unless headers["id"]
      end
      if connect?
        unless headers["accept-version"].split(",").include?(STOMP_VERSION)
          error = ClientError.new("client must support STOMP version #{STOMP_VERSION}")
          error!(error, version: STOMP_VERSION)
          raise error
        end
      end
    end

  private

    def connect?
      ["STOMP", "CONNECT"].include?(command)
    end
  end
end
