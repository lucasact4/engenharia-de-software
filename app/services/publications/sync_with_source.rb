module Publications
  # Retira ou invalida a publicação quando a fonte muda de audiência, na transação do alerta.
  class SyncWithSource < ApplicationService
    attr_reader :actor

    def initialize(actor:, alert:)
      @actor = actor
      @alert = alert
    end

    def call
      authorize!(@alert, :change_audience?)
      publication = @alert.publication
      return if publication.nil? || publication.source_compatible?

      if publication.published?
        Withdraw.call(actor: actor, publication: publication, source_alert: @alert,
                      reason: "Fonte deixou de autorizar esta audiência.", system_reason: "source_audience_changed")
      elsif !publication.review_not_submitted?
        changes = { "review_status" => [ publication.review_status, "not_submitted" ] }
        publication.update!(review_status: "not_submitted")
        AuditEvent.record!(actor: actor, action: "publication.review_invalidated", subject: publication,
                           changes: changes, metadata: { system_reason: "source_audience_changed" })
      end
      publication
    end
  end
end
