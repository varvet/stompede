module Stompede
  class Subscription
    def initialize(session, frame)
      @session = session
      @frame = frame
    end

    def validate!
      raise ClientError, "subscription does not include a destination" unless @frame["destination"]
      raise ClientError, "subscription does not include an id" unless @frame["id"]
    end
  end
end
