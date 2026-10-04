module Alerts
  # Edita o relato canônico e sincroniza a versão e a audiência da mesma publicação.
  class UpdateContent < ApplicationService
    PERMITTED = %i[
      title description category_id category_other_description
      location_source location_id location_description latitude longitude location_accuracy_meters location_captured_at
      reported_severity requested_visibility
    ].freeze

    attr_reader :actor

    def initialize(actor:, alert:, attributes: {}, photos: [], photo_order: nil, removed_photo_ids: [], lock_version: nil)
      @actor = actor
      @alert = alert
      @attributes = attributes.to_h.symbolize_keys.slice(*PERMITTED)
      @photos = Array(photos).compact_blank
      @lock_version = lock_version
      @photo_order, @removed_photo_ids = photo_order, removed_photo_ids
    end

    def call
      authorize!(@alert, :update_content?)
      apply_lock_version(@alert, @lock_version)
      requested = @attributes.delete(:requested_visibility)
      @alert.requested_visibility = requested if requested
      @alert.visibility = requested == "internal" ? "internal" : "restricted" if requested && !@alert.publication_blocked?
      @alert.assign_attributes(@attributes)
      selection = PhotoSelection.new(@alert, uploads: @photos, order: @photo_order, removed_ids: @removed_photo_ids)
      selection.prepare!
      @alert.updated_at = Time.current if selection.changed?
      fields = @alert.changed - %w[lock_version updated_at created_at]
      return @alert if fields.empty? && !selection.changed?

      Alert.transaction do
        @alert.save!
        selection.persist_order!
        flagged = self.class.flag_publication(actor, @alert)
        AuditEvent.record!(
          actor: actor, action: "alert.content_updated", subject: @alert,
          metadata: { fields: fields, photos_count: @photos.size, removed_photo_ids: selection.removed_ids, photo_order: @alert.photo_order, source: (flagged ? "publication_flagged" : nil) }
        )
      end
      @alert
    end

    def self.flag_publication(actor, alert)
      Publications::SyncOccurrence.call(actor: actor, alert: alert, content_changed: true, request_external: true)
      alert.publication.present?
    end
  end
end
