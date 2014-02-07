require "stompede/stomp/message"
require "stompede/stomp/ruby_parser"

module Stompede
  module Stomp
    class Error < StandardError
    end

    # Errors raised by the Stomp::Parser.
    class ParseError < Error
    end

    # Raised when the Stomp::Parser tries to buffer
    # more than what has been allowed.
    #
    # Protects against malicious clients trying to
    # fill the available server memory by sending an
    # unbounded amount of data.
    class BufferLimitExceeded < ParseError
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

    Parser = RubyParser

    @max_message_size = 1024 * 10 # 10KB

    class << self
      attr_accessor :max_message_size

      # Create a parse error from a string chunk and an index.
      #
      # @api private
      # @param [String] chunk
      # @param [Integer] index
      # @return [ParseError]
      def build_parse_error(chunk, index)
        ctx = 7
        min = [0, index - ctx].max
        len = ctx + 1 + ctx
        context = chunk.byteslice(min, len)

        idx = index - min
        chr = context[idx]
        context[idx] = " -->#{chr}<-- "

        ParseError.new("unexpected #{chr} in chunk (#{context.inspect})")
      end
    end
  end
end
