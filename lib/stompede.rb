require "celluloid"
require "celluloid/io"

require "securerandom"

require "stompede/version"

require "stompede/error"
require "stompede/stomp/parser"
require "stompede/stomp/message"

require "stompede/connector"
require "stompede/base"
require "stompede/session"
require "stompede/subscription"

begin
  # require "stompede/stomp/parser_native"
rescue LoadError
  # Native parser not available, fall back to pure-ruby implementation.
end

module Stompede
  BUFFER_SIZE = 10 * 1024
  STOMP_VERSION = "1.2" # version of the STOMP protocol we support
end
