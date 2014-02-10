class CrashMonitor
  include Celluloid

  def initialize(timeout = 0.5)
    @timeout = timeout
  end

  def observe(actor)
    link actor
  end

  trap_exit :dying_actor

  def wait_for_crash
    timeout(@timeout) do
      # check if the actor has already crashes, in that case, return reason,
      # otherwise, wait for crash.
      if defined?(@reason)
        @reason
      else
        wait :crash
      end
    end
  end

  def wait_for_crash!
    reason = wait_for_crash
    abort reason if reason
  end

  alias_method :wait_for_terminate, :wait_for_crash!

  def dying_actor(actor, reason)
    @reason = reason
    signal :crash, reason
  end
end
