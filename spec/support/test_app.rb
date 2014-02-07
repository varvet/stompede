class TestApp
  class MooError < StandardError; end

  def initialize(latch, options = {})
    @latch = latch
    @error = Array(options[:error])
  end

  [:on_open, :on_connect, :on_subscribe, :on_send, :on_unsubscribe, :on_disconnect, :on_close].each do |m|
    define_method(m) do |*args|
      @latch.push([m, *args])
      raise MooError, "MOOOO!" if @error.include?(m)
    end
  end
end
