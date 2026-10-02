module Alerts
  # O autor pode restringir; ampliar ou liberar a divulgação exige administrador e motivo.
  class ChangeAudience < ApplicationService
    attr_reader :actor

    def initialize(actor:, alert:, requested_visibility:, reason: nil, lock_version: nil)
      @actor = actor
      @alert = alert
      @requested = requested_visibility.to_s
      @reason = reason
      @lock_version = lock_version
    end

    def call
      authorize!(@alert, :change_audience?)
      unless @requested == "restricted"
        authorize!(@alert, :expand_audience?)
        require_reason!(@reason, @alert)
      end

      apply_lock_version(@alert, @lock_version)
      @alert.requested_visibility = @requested
      @alert.visibility = @requested == "internal" ? "internal" : "restricted"
      @alert.publication_blocked = false unless @requested == "restricted"
      changes = @alert.changes.slice("requested_visibility", "visibility", "publication_blocked")
      return @alert if changes.empty?

      Alert.transaction do
        @alert.save!
        AuditEvent.record!(actor: actor, action: "alert.audience_changed", subject: @alert, changes: changes, reason: @reason)
        Publications::SyncWithSource.call(actor: actor, alert: @alert)
      end
      @alert
    end
  end
end
