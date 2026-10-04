module Publications
  # A revisão vale somente para a versão de conteúdo lida pelo revisor.
  class Review < ApplicationService
    DECISIONS = %w[approve reject].freeze

    class StaleReview < StandardError; end

    attr_reader :actor

    def initialize(actor:, publication:, decision:, reviewed_content_version:, reason: nil, lock_version: nil)
      @actor = actor
      @publication = publication
      @decision = decision.to_s
      @reviewed_content_version = reviewed_content_version.to_i
      @reason = reason
      @lock_version = lock_version
    end

    def call
      authorize!(@publication, :review?)
      raise ArgumentError, "decisão inválida: #{@decision}" unless DECISIONS.include?(@decision)
      raise StaleReview, "o conteúdo mudou desde a leitura do revisor" if @reviewed_content_version != @publication.content_version

      unless @publication.review_pending?
        @publication.errors.add(:review_status, :not_pending)
        raise ActiveRecord::RecordInvalid, @publication
      end
      require_reason!(@reason, @publication) if @decision == "reject"
      ensure_source_compatible! if @decision == "approve"

      apply_lock_version(@publication, @lock_version)
      @publication.assign_attributes(
        review_status: @decision == "approve" ? "approved" : "rejected",
        approval_method: @decision == "approve" ? "administrator" : nil,
        reviewed_content_version: @reviewed_content_version,
        reviewed_by: actor,
        reviewed_at: Time.current,
        review_reason: @reason
      )
      @publication.source_changed_at = nil if @decision == "approve"
      if @publication.occurrence?
        @publication.assign_attributes(visibility: @decision == "approve" ? "public_external" : "internal",
                                      state: "published", published_at: @publication.published_at || Time.current,
                                      withdrawn_at: nil, moderation_blocked: false)
        if @decision == "reject" && @publication.moderation_blocked_in_database
          @publication.assign_attributes(state: "withdrawn", withdrawn_at: Time.current, moderation_blocked: true)
        end
      end
      changes = @publication.changes

      Publication.transaction do
        @publication.save!
        AuditEvent.record!(actor: actor, action: "publication.#{@decision == 'approve' ? 'approved' : 'rejected'}",
                           subject: @publication, changes: changes, reason: @reason)
      end
      @publication
    end

    private

      def ensure_source_compatible!
        return if @publication.source_compatible?

        @publication.errors.add(:alert, :incompatible_audience)
        raise ActiveRecord::RecordInvalid, @publication
      end
  end
end
