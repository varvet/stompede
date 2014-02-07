require "stompede/stomp/ruby_parser"

module Stompede
  module Stomp
    module Parser
      @default = RubyParser
      @max_message_size = 1024 * 10 # 10KB

      class << self
        attr_accessor :max_message_size

        # Initialize a parser that responds to #parse.
        #
        # @example
        #   parser = Parser.new do |message|
        #     # handle message
        #   end
        #
        #   loop do
        #     # raises ParseError if data is malformatted
        #     parser.parse(read_chunk)
        #   end
        #
        # @param [Integer] max_message_size (Parser.max_message_size)
        # @yield [message]
        # @yieldparam [Stompede::Stomp::Message] message
        # @return [#parse]
        #
        # @raise [ArgumentError] if no block is given
        def new(max_message_size = max_message_size, &block)
          unless block_given?
            raise ArgumentError, "no block given"
          end

          @default.new(max_message_size, &block)
        end

        # Create a parse error from a string chunk and an index.
        #
        # @api private
        # @param [String] chunk
        # @param [Integer] index
        # @return [ParseError]
        def build_error(chunk, index)
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
end
