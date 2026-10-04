module Publications
  # Retira uma publicação do ar com motivo. Não altera o atendimento do Alert de origem.
  class Withdraw < ApplicationService
    attr_reader :actor

    def initialize(actor:, publication:, reason:, system_reason: nil, source_alert: nil)
      @actor = actor
      @publication = publication
      @reason = reason
      @system_reason = system_reason
      @source_alert = source_alert
    end

    def call
      if @source_alert
        authorize!(@source_alert, :change_audience?)
        unless @publication.alert_id == @source_alert.id && !@publication.source_compatible?
          raise Pundit::NotAuthorizedError, "fonte não autoriza a retirada"
        end
      else
        authorize!(@publication, :withdraw?)
      end
      require_reason!(@reason, @publication)
      return @publication if @publication.withdrawn?

      @publication.assign_attributes(state: "withdrawn", withdrawn_at: Time.current, moderation_blocked: @source_alert.nil?)
      changes = @publication.changes
      Publication.transaction do
        @publication.save!
        AuditEvent.record!(actor: actor, action: "publication.withdrawn", subject: @publication,
                           changes: changes, reason: @reason, metadata: { system_reason: @system_reason })
      end
      @publication
    end
  end
end
