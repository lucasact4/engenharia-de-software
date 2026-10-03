module Alerts
  # Edição pelo autor sinaliza revisão da publicação vinculada, sem reescrever seu texto.
  class UpdateContent < ApplicationService
    PERMITTED = %i[
      title description category_id category_other_description
      location_source location_id latitude longitude location_accuracy_meters location_captured_at
      reported_severity
    ].freeze

    attr_reader :actor

    def initialize(actor:, alert:, attributes: {}, photos: [], lock_version: nil)
      @actor = actor
      @alert = alert
      @attributes = attributes.to_h.symbolize_keys.slice(*PERMITTED)
      @photos = Array(photos).compact_blank
      @lock_version = lock_version
    end

    def call
      authorize!(@alert, :update_content?)
      apply_lock_version(@alert, @lock_version)
      @alert.assign_attributes(@attributes)
      @alert.photos = @alert.photos.blobs + @photos if @photos.any?
      fields = @alert.changed - %w[lock_version]
      return @alert if fields.empty? && @photos.empty?

      Alert.transaction do
        @alert.save!
        flagged = self.class.flag_publication(actor, @alert)
        AuditEvent.record!(
          actor: actor, action: "alert.content_updated", subject: @alert,
          metadata: { fields: fields, photos_count: @photos.size, source: (flagged ? "publication_flagged" : nil) }
        )
      end
      @alert
    end

    # Fonte alterada marca a publicação para nova revisão, sem copiar o texto operacional.
    def self.flag_publication(actor, alert)
      publication = alert.publication
      return false if publication.nil?

      publication.update!(source_changed_at: Time.current)
      AuditEvent.record!(
        actor: actor, action: "publication.source_changed", subject: publication,
        changes: { "source_changed_at" => [ nil, publication.source_changed_at ] }
      )
      true
    end
  end
end
