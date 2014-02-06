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

    def validate!
      if @frame.command == "SUBSCRIBE"
        raise ClientError, "subscription does not include a destination" unless destination
      end
      raise ClientError, "subscription does not include an id" unless id
    end
  end
end
