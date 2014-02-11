module Stompede
  class Frame
    attr_reader :command, :headers, :body

    def initialize(command, headers, body)
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
  end
end
