class TestApp < Stompede::Base
  class MooError < StandardError; end

  def initialize(socket, latch, options = {})
    super(socket)
    @latch = latch
    @error = Array(options[:error])
    @detach = Array(options[:detach])
  end

  [:on_open, :on_connect, :on_subscribe, :on_send, :on_unsubscribe, :on_disconnect, :on_close].each do |m|
    define_method(m) do |*args|
      args.last.detach! if @detach.include?(m)
      @latch.push([m, *args])
      raise MooError, "MOOOO!" if @error.include?(m)
    end
  end
end
