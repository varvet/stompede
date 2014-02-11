module Stompede
  module Stomp
    class Error < StandardError
    end

    # Errors raised by the Stomp::Parser.
    class ParseError < Error
    end

    # Raised when the Stomp::Parser has reached the
    # limit for how large a Stomp::Message may be.
    #
    # Protects against malicious clients trying to
    # fill the available memory by sending very large
    # messages, for example by sending an unlimited
    # amount of headers.
    class MessageSizeExceeded < ParseError
    end
  end
end
