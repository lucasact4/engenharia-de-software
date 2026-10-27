class CampusMapController < PortalController
  allow_unauthenticated_access only: :index

  def index
    authorize Publication, :index?
    @map_data = CampusMap::MapData.new(viewer: Current.user).call
  end
end
