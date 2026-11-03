module Publications
  # Remove do mural sem apagar comentários, denúncias ou o histórico auditável.
  class Delete < ApplicationService
    attr_reader :actor

    def initialize(actor:, publication:, reason:)
      @actor = actor
      @publication = publication
      @reason = reason
    end

    def call
      authorize!(@publication, :destroy?)
      require_reason!(@reason, @publication)

      @publication.assign_attributes(state: "withdrawn", withdrawn_at: Time.current, moderation_blocked: true)
      changes = @publication.changes
      Publication.transaction do
        @publication.save!
        AuditEvent.record!(actor: actor, action: "publication.deleted", subject: @publication,
                           changes: changes, reason: @reason)
      end
      @publication
    end
  end
end
