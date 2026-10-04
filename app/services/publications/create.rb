module Publications
  # Rascunhos de avisos e notícias. Ocorrências usam a publicação criada pelo autor.
  class Create < ApplicationService
    PERMITTED = %i[kind title body visibility expires_at comments_enabled photos].freeze

    attr_reader :actor

    def initialize(actor:, attributes:, alert: nil)
      @actor = actor
      @attributes = attributes.to_h.symbolize_keys.slice(*PERMITTED)
      @alert = alert
    end

    def call
      authorize!(Publication, :create?)
      if @alert || @attributes[:kind].to_s == "occurrence"
        raise Pundit::NotAuthorizedError, "ocorrências são publicadas pelo próprio autor"
      end
      publication = Publication.new(@attributes)
      publication.author = actor

      Publication.transaction do
        publication.save!
        AuditEvent.record!(
          actor: actor, action: "publication.created", subject: publication,
          changes: { "visibility" => [ nil, publication.visibility ] },
          metadata: { kind: publication.kind }
        )
      end
      publication
    end
  end
end
