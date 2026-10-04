module Publications
  # Edição relevante invalida a aprovação e retira o conteúdo do ar até nova revisão.
  class Update < ApplicationService
    PERMITTED = %i[title body visibility expires_at comments_enabled photos].freeze

    attr_reader :actor

    def initialize(actor:, publication:, attributes:, lock_version: nil)
      @actor = actor
      @publication = publication
      @attributes = attributes.to_h.symbolize_keys.slice(*PERMITTED)
      @lock_version = lock_version
    end

    def call
      authorize!(@publication, :update?)
      apply_lock_version(@publication, @lock_version)
      photos = Array(@attributes.delete(:photos)).compact_blank
      @publication.assign_attributes(@attributes)
      @publication.photos = @publication.photos.blobs + photos if photos.any?
      fields = @publication.changed - %w[lock_version]
      fields << "photos" if photos.any?
      return @publication if fields.empty?

      if photos.any? || (fields & Publication::RELEVANT_ATTRIBUTES).any?
        @publication.content_version += 1
        @publication.review_status = "not_submitted"
        if @publication.published?
          @publication.state = "draft"
          @publication.published_at = nil
        end
      end
      changes = @publication.changes

      Publication.transaction do
        @publication.save!
        AuditEvent.record!(actor: actor, action: "publication.updated", subject: @publication,
                           changes: changes, metadata: { fields: fields })
      end
      @publication
    end
  end
end
