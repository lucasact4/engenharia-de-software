module Publications
  # Cria rascunho editorial; ocorrências exigem fonte compatível e pânico não pode ser divulgado.
  class Create < ApplicationService
    PERMITTED = %i[kind title body visibility expires_at comments_enabled].freeze

    attr_reader :actor

    def initialize(actor:, attributes:, alert: nil)
      @actor = actor
      @attributes = attributes.to_h.symbolize_keys.slice(*PERMITTED)
      @alert = alert
    end

    def call
      authorize!(Publication, :create?)
      publication = Publication.new(@attributes)
      publication.author = actor
      publication.alert = @alert
      publication.kind = "occurrence" if @alert && publication.kind.blank?

      Publication.transaction do
        publication.save!
        AuditEvent.record!(
          actor: actor, action: "publication.created", subject: publication,
          changes: { "visibility" => [ nil, publication.visibility ] },
          metadata: { kind: publication.kind, source: (@alert ? "alert" : nil) }
        )
      end
      publication
    end
  end
end
