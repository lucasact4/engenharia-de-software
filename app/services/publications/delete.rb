module Publications
  # Remove do mural sem apagar comentários, denúncias ou o histórico auditável.
  class Delete < ApplicationService
    attr_reader :actor

    def initialize(actor:, publication:, reason:, by_author: false)
      @actor = actor
      @publication = publication
      @reason = reason
      @by_author = by_author
    end

    def call
      @publication.with_lock do
        authorize!(@publication, @by_author ? :delete_own? : :destroy?)
        require_reason!(@reason, @publication)

        @publication.assign_attributes(state: "withdrawn", withdrawn_at: Time.current, moderation_blocked: true)
        changes = @publication.changes
        @publication.save!
        AuditEvent.record!(actor: actor, action: "publication.deleted", subject: @publication,
                           changes: changes, reason: @reason)
      end
      @publication
    end
  end
end
