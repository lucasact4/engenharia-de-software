# Lista privada de salvos, revalidada pelo acesso atual (salvar não concede acesso).
# Aparece como a aba Salvos do próprio perfil, como no Instagram.
class SavedPublicationsController < PortalController
  include ProfileGrid

  def index
    authorize :panel, :show?
    @user = User.find(Current.user.id)
    query = BookmarkedPublicationsQuery.new(Current.user)
    @pagy, records = pagy(query.call.order(published_at: :desc, id: :desc), limit: GRID_PER_PAGE)
    @grid_cards = PublicationProjection.collection(records, viewer: Current.user)
    @unavailable = query.unavailable_count
    load_own_profile_summary(@user)
  end
end
