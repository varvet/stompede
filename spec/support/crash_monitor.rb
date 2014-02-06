class CrashMonitor
  include Celluloid

  def initialize(actor)
    link actor
  end

  trap_exit :dying_actor

  def wait_for_crash
    timeout(2) do
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

  def dying_actor(actor, reason)
    @reason = reason
    signal :crash, reason
  end
end
