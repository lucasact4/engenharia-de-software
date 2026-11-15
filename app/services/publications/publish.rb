module Publications
  # Publica a versão aprovada, com fonte compatível e validade vigente.
  class Publish < ApplicationService
    attr_reader :actor

    def initialize(actor:, publication:, lock_version: nil)
      @actor = actor
      @publication = publication
      @lock_version = lock_version
    end

    def call
      authorize!(@publication, :publish?)
      now = Time.current
      check!(:requires_current_approval) { @publication.approved_for_current_content? }
      check!(:source_review_pending) { @publication.source_changed_at.nil? }
      check!(:incompatible_source) { @publication.source_compatible? }
      check!(:expires_in_future) { @publication.expires_at.nil? || @publication.expires_at > now }
      check!(:notice_requires_expiration) { !@publication.notice? || @publication.expires_at.present? }

      apply_lock_version(@publication, @lock_version)
      @publication.assign_attributes(state: "published", published_at: now, withdrawn_at: nil)
      changes = @publication.changes

      Publication.transaction do
        @publication.save!
        AuditEvent.record!(actor: actor, action: "publication.published", subject: @publication, changes: changes)
      end
      @publication
    end

    private

      def check!(error)
        return if yield

        @publication.errors.add(:base, error)
        raise ActiveRecord::RecordInvalid, @publication
      end
  end
end
