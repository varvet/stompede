module Stompede
  class Frame
    attr_reader :session, :command, :headers, :body

    def initialize(session, command, headers, body)
      @session = session
      @command = command
      @headers = headers
      @body = body
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
      receipt_headers["receipt-id"] = headers["receipt"]
      session.write(StompParser::Frame.new("RECEIPT", receipt_headers, "").to_str)
    rescue IOError
      raise Disconnected
    end
  end
end
