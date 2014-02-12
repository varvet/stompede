module Stompede
  class ErrorFrame
    attr_reader :headers

    def initialize(exception, headers = {})
      @exception = exception
      @headers = headers
      @headers["content-type"] = "text/plain"
    end

    def command
      :error
    end

    def body
      "#{@exception.class}: #{@exception.message}\n\n#{Array(@exception.backtrace).join("\n")}"
    end

    def to_str
      StompParser::Frame.new("ERROR", headers, body).to_str
    end
    alias_method :to_s, :to_str
  end
end
