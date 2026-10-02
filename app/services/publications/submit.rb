module Publications
  # Envia a versão atual para revisão (not_submitted ou rejected -> pending).
  class Submit < ApplicationService
    attr_reader :actor

    def initialize(actor:, publication:)
      @actor = actor
      @publication = publication
    end

    def call
      authorize!(@publication, :submit?)
      unless @publication.review_not_submitted? || @publication.review_rejected?
        @publication.errors.add(:review_status, :not_submittable)
        raise ActiveRecord::RecordInvalid, @publication
      end

      @publication.review_status = "pending"
      changes = @publication.changes
      Publication.transaction do
        @publication.save!
        AuditEvent.record!(actor: actor, action: "publication.submitted", subject: @publication, changes: changes)
      end
      @publication
    end
  end
end
