require "stompede/stomp/error"
require "stompede/stomp/message"
require "stompede/stomp/ruby_parser"

case RUBY_ENGINE
when "ruby", "rbx"
  require "stompede/stomp/c_parser"
end

module Stompede
  module Stomp
    DEFAULTS = {}
    Parser = DEFAULTS[RUBY_ENGINE] || RubyParser

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
        context = chunk.byteslice(min, len).force_encoding("BINARY")

        idx = index - min
        chr = context[idx]
        context[idx] = " -->#{chr}<-- "

        ParseError.new("unexpected #{chr} in chunk (#{context.inspect})")
      end
    end
  end
end
