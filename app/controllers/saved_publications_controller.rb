# Lista privada de salvos, revalidada pelo acesso atual (salvar não concede acesso).
class SavedPublicationsController < PortalController
  def index
    authorize :panel, :show?
    query = BookmarkedPublicationsQuery.new(Current.user)
    @pagy, records = pagy(query.call.order(published_at: :desc, id: :desc), limit: 10)
    @cards = PublicationProjection.collection(records, viewer: Current.user)
    @unavailable = query.unavailable_count
  end
end
