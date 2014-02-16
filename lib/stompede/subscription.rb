module Stompede
  class Subscription
    attr_reader :session

    ACK_MODES = { "client-individual" => :individual, "client" => :cumulative, "auto" => :auto, nil => :auto }
    DEFAULT_TIMEOUT = 5

    def initialize(session, frame)
      @session = session
      @frame = frame
    end

    def id
      @frame["id"]
    end

    def destination
      @frame["destination"]
    end

    def ack_mode
      ACK_MODES[@frame["ack"]] or raise ClientError, "invalid ack mode #{@frame["ack"].inspect}"
    end

    def message(body, headers = {})
      timeout = headers.delete(:timeout) || DEFAULT_TIMEOUT # TODO: tests!
      headers = {
        "subscription" => id,
        "destination" => destination,
        "message-id" => SecureRandom.uuid
      }
      if ack_mode == :auto
        @session.write(StompParser::Frame.new("MESSAGE", headers, body))
        nil
      else
        headers["ack"] = headers["message-id"]
        message = StompParser::Frame.new("MESSAGE", headers, body)
        @session.write_and_wait_for_ack(self, message, timeout)
      end
    end

    def message!(body, headers = {})
      response = message(body, headers)
      raise Nack, "client did not acknowledge message" if response and response.command == :nack
    end
  end
end
