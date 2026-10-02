module Alerts
  # Restringe o atendimento e bloqueia a divulgação, preservando o pedido original do autor.
  class Restrict < ApplicationService
    attr_reader :actor

    def initialize(actor:, alert:, reason:, lock_version: nil)
      @actor = actor
      @alert = alert
      @reason = reason
      @lock_version = lock_version
    end

    def call
      authorize!(@alert, :restrict?)
      require_reason!(@reason, @alert)
      apply_lock_version(@alert, @lock_version)
      @alert.visibility = "restricted"
      @alert.publication_blocked = true
      changes = @alert.changes.slice("visibility", "publication_blocked")

      Alert.transaction do
        @alert.save! if changes.any?
        AuditEvent.record!(actor: actor, action: "alert.restricted", subject: @alert, changes: changes, reason: @reason)
        Publications::SyncWithSource.call(actor: actor, alert: @alert)
      end
      @alert
    end
  end
end
