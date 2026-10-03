# Favoritos da própria pessoa, revalidados contra o que está no ar para ela agora:
# salvar não concede acesso, e rascunhos ou retiradas nunca reaparecem pelos salvos.
class BookmarkedPublicationsQuery
  def initialize(viewer)
    @viewer = viewer
  end

  def call
    return Publication.none unless @viewer&.active?

    relation = Publication.where(id: @viewer.publication_bookmarks.select(:publication_id))
    PublicationPolicy::FeedScope.new(@viewer, relation).resolve
  end

  # Quantos salvos deixaram de estar acessíveis (sem revelar quais).
  def unavailable_count
    return 0 unless @viewer&.active?

    @viewer.publication_bookmarks.count - call.count
  end
end
