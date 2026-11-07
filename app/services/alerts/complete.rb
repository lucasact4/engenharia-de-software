module Alerts
  # O autor informa a resolução; a matriz e as permissões do atendimento não são ampliadas.
  class Complete < ApplicationService
    attr_reader :actor

    def initialize(actor:, alert:, lock_version:)
      @actor = actor
      @alert = alert
      @lock_version = lock_version
    end

    def call
      @alert.with_lock do
        authorize!(@alert, :complete?)
        return @alert if @alert.resolved?

        apply_lock_version(@alert, @lock_version)
        now = Time.current
        @alert.assign_attributes(status: "resolved", resolved_at: now, status_changed_at: now)
        changes = @alert.changes.slice(*AuditEvent::ALLOWED_CHANGES.fetch("Alert"))
        @alert.save!
        AuditEvent.record!(
          actor: actor, action: "alert.status_changed", subject: @alert, changes: changes,
          metadata: { source: "author_completion" }
        )
      end
      @alert
    end
  end
end
