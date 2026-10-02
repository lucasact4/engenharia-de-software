# Favoritos da própria pessoa, revalidados contra o acesso atual: salvar não concede acesso.
class BookmarkedPublicationsQuery
  def initialize(viewer)
    @viewer = viewer
  end

  def call
    return Publication.none unless @viewer&.active?

    relation = Publication.where(id: @viewer.publication_bookmarks.select(:publication_id))
    PublicationPolicy::Scope.new(@viewer, relation).resolve
  end
end
