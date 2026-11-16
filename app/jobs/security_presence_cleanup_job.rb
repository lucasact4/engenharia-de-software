class SecurityPresenceCleanupJob < ApplicationJob
  queue_as :maintenance

  def perform
    SecurityPresence.where(reported_at: ..SecurityPresence::FRESH_FOR.ago).delete_all
  end
end
