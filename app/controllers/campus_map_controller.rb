class CampusMapController < PortalController
  allow_unauthenticated_access only: :index

  def index
    authorize Publication, :index?
    @categories = Category.active.ordered.to_a
    @map_statuses = CampusMap::MapData::ACTIVE_STATUSES
    @map_severities = CampusMap::MapData::REPORTED_SEVERITIES
    @map_filters = {}
    selected_category = @categories.find { |category| category.id.to_s == params[:category_id].to_s }
    @map_filters[:category_id] = selected_category.id if selected_category
    @map_filters[:status] = params[:status].to_s if @map_statuses.include?(params[:status].to_s)
    allowed_severities = @map_severities + [ "not_reported" ]
    @map_filters[:severity] = params[:severity].to_s if allowed_severities.include?(params[:severity].to_s)
    @map_data = CampusMap::MapData.new(viewer: Current.user, filters: @map_filters).call
  end
end
