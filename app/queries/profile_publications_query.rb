# Publicações no ar de uma pessoa, para a grade do perfil. Quem lê só vê o que o mural já
# mostraria (FeedScope). No perfil de outra pessoa entram apenas ocorrências assinadas:
# avisos e notícias levam a identidade da equipe e relatos anônimos nunca são ligados ao autor.
class ProfilePublicationsQuery
  def initialize(person, viewer:)
    @person = person
    @viewer = viewer
  end

  def call
    scope = PublicationPolicy::FeedScope.new(@viewer, Publication.where(author_id: @person.id)).resolve
    unless @viewer&.id == @person.id
      scope = scope.occurrence.where(alert_id: Alert.occurrence.where(anonymous_public: false).select(:id))
    end
    scope.order(published_at: :desc, id: :desc)
  end
end
