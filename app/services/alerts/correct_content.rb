module Alerts
  # Correção administrativa de texto e categoria de uma ocorrência de outra pessoa.
  # Exige motivo e fica auditada; não altera localização, severidade relatada, fotos nem audiência.
  class CorrectContent < ApplicationService
    PERMITTED = %i[title description category_id category_other_description].freeze

    attr_reader :actor

    def initialize(actor:, alert:, attributes:, reason:, lock_version: nil)
      @actor = actor
      @alert = alert
      @attributes = attributes.to_h.symbolize_keys.slice(*PERMITTED)
      @reason = reason
      @lock_version = lock_version
    end

    def call
      authorize!(@alert, :correct_content?)
      require_reason!(@reason, @alert)
      apply_lock_version(@alert, @lock_version)
      @alert.assign_attributes(@attributes)
      fields = @alert.changed - %w[lock_version]
      return @alert if fields.empty?

      Alert.transaction do
        @alert.save!
        flagged = UpdateContent.flag_publication(actor, @alert)
        AuditEvent.record!(
          actor: actor, action: "alert.content_corrected", subject: @alert, reason: @reason,
          metadata: { fields: fields, source: (flagged ? "publication_flagged" : nil) }
        )
      end
      @alert
    end
  end
end
