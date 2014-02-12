module Stompede
  class Subscription
    attr_reader :session

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

    def message(body, headers = {})
      headers = {
        "subscription" => id,
        "destination" => destination,
        "message-id" => SecureRandom.uuid
      }
      @session.safe_write(StompParser::Frame.new("MESSAGE", headers, body))
    end
  end
end
