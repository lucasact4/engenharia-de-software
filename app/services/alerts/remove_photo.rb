module Alerts
  # Remove uma foto do próprio alerta. Só aceita anexo que pertença a ele (nunca blob por ID).
  #
  # Banco e arquivo não têm atomicidade conjunta: o vínculo é apagado e auditado na transação;
  # o arquivo só é expurgado depois do commit, em job. Se a transação falhar, nada é apagado;
  # se o expurgo falhar, sobra um arquivo sem vínculo (inacessível pelas rotas), nunca uma foto
  # válida perdida. Blob compartilhado com outro anexo não é expurgado.
  class RemovePhoto < ApplicationService
    attr_reader :actor

    def initialize(actor:, alert:, attachment_id:, reason: nil, lock_version: nil)
      @actor = actor
      @alert = alert
      @attachment_id = attachment_id
      @reason = reason
      @lock_version = lock_version
    end

    def call
      authorize!(@alert, :remove_photo?)
      require_reason!(@reason, @alert) unless @alert.author_id == actor.id
      attachment = @alert.photos_attachments.find(@attachment_id)
      blob = attachment.blob

      Alert.transaction do
        @alert.lock!
        apply_lock_version(@alert, @lock_version)
        attachment.delete
        @alert.update_columns(photo_order: Array(@alert.photo_order) - [ attachment.id ])
        @alert.touch
        AuditEvent.record!(
          actor: actor, action: "alert.photo_removed", subject: @alert, reason: @reason,
          metadata: { photos_count: @alert.photos_attachments.count }
        )
        UpdateContent.flag_publication(actor, @alert)
      end
      blob.purge_later unless ActiveStorage::Attachment.exists?(blob_id: blob.id)
      @alert
    end
  end
end
