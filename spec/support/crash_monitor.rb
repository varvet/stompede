class CrashMonitor
  include Celluloid

  def initialize(actor, timeout = 0.5)
    link actor
    @actor = actor
    @timeout = timeout
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

  def ensure_alive!
    timeout(@timeout) do
      sleep(0.01) until idle?
    end
  end

  def idle?
    @actor.tasks.none?(&:running?) && @actor.mailbox.size.zero?
  end

  def dying_actor(actor, reason)
    @reason = reason
    signal :crash, reason
  end
end
