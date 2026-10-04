module Publications
  # Uma publicação por ocorrência. Aprovação externa nunca cria cópia do relato ou das fotos.
  class SyncOccurrence < ApplicationService
    attr_reader :actor

    def initialize(actor:, alert:, content_changed: false, request_external: false)
      @actor, @alert = actor, alert
      @content_changed, @request_external = content_changed, request_external
    end

    def call
      authorize!(@alert, :change_audience?)
      return unless @alert.occurrence?

      source = @alert
      Alert.transaction do
        # Outra instância preserva os callbacks de upload ainda pendentes na criação/edição.
        @alert = Alert.find(@alert.id)
        @alert.lock!
        authorize!(@alert, :change_audience?)
        publication = @alert.publication
        return if publication.nil? && @alert.requested_restricted?

        publication ||= Publication.new(kind: "occurrence", alert: @alert, author: @alert.author, visibility: "internal")
        publication.lock! if publication.persisted?
        publication.content_version += 1 if publication.persisted? && @content_changed
        if @alert.publication_blocked? || @alert.requested_restricted? || publication.moderation_blocked?
          publication.assign_attributes(state: "withdrawn", withdrawn_at: Time.current, visibility: "internal")
        else
          publication.assign_attributes(state: "published", published_at: publication.published_at || Time.current, withdrawn_at: nil)
          decide_visibility(publication)
        end
        changes = publication.changes
        publication.save!
        AuditEvent.record!(actor: actor, action: "publication.occurrence_synced", subject: publication,
                           changes: changes, metadata: { source: "canonical_alert", decision: publication.review_status })
        source.association(:publication).reset
        @alert.association(:publication).reset
        publication
      end
    end

    private

      def decide_visibility(publication)
        return if @alert.requested_public_external? && !@content_changed && !@request_external && publication.public_external? && publication.approved_for_current_content?

        publication.visibility = "internal"
        publication.source_changed_at = nil
        if @alert.requested_public_external?
          if User.find(@alert.author_id).verified?
            publication.assign_attributes(visibility: "public_external", review_status: "approved", approval_method: "verified_author",
                                          reviewed_content_version: publication.content_version, reviewed_at: Time.current,
                                          reviewed_by: nil, review_reason: nil)
          else
            publication.assign_attributes(review_status: "pending", approval_method: nil, reviewed_content_version: nil,
                                          reviewed_at: nil, reviewed_by: nil)
          end
        else
          publication.assign_attributes(review_status: "not_submitted", approval_method: nil, reviewed_content_version: nil,
                                        reviewed_at: nil, reviewed_by: nil, review_reason: nil)
        end
      end
  end
end
