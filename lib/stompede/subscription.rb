module Stompede
  class Subscription
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
      raise ClientError, "subscription does not include a destination" unless destination
      raise ClientError, "subscription does not include an id" unless id
    end
  end
end
