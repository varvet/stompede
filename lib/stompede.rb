require "celluloid"
require "celluloid/io"

require "securerandom"

require "stompede/version"
require "stompede/error"

require "stompede/stomp"

require "stompede/base"
require "stompede/session"
require "stompede/subscription"

module Stompede
  BUFFER_SIZE = 10 * 1024
  STOMP_VERSION = "1.2" # version of the STOMP protocol we support
end
