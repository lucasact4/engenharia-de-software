# Local aproximado de um pânico público: local cadastrado, descrição informada ou o prédio oficial
# mais próximo do GPS. Nunca mostra as coordenadas exatas.
module PublicWarningsHelper
  NEARBY_BUILDING_KM = 0.4

  BUILDING_POINTS = CampusMap::MapData::OFFICIAL_BUILDINGS.filter_map do |feature|
    name = feature.dig("properties", "name").to_s
    next if name.blank? || name.start_with?("Edifício da UFRPE")

    geometry = feature.fetch("geometry")
    ring = geometry["type"] == "MultiPolygon" ? geometry["coordinates"].first.first : geometry["coordinates"].first
    [ name, ring.sum { |point| point[1] } / ring.size, ring.sum { |point| point[0] } / ring.size ]
  end.freeze

  def public_warning_place(alert)
    return alert.location.name if alert.location
    return alert.location_description if alert.location_description.present?

    building = nearest_building(alert.latitude, alert.longitude) if alert.latitude.present? && alert.longitude.present?
    building ? "perto de #{building}" : "no campus"
  end

  private

    def nearest_building(latitude, longitude)
      name, distance = BUILDING_POINTS.map do |building, lat, lng|
        [ building, haversine_km(latitude.to_f, longitude.to_f, lat, lng) ]
      end.min_by(&:last)
      return unless name && distance <= NEARBY_BUILDING_KM

      return name unless name == name.upcase

      name.split.map { |word| %w[DE DA DO DAS DOS E].include?(word) ? word.downcase : word.capitalize }.join(" ")
    end

    def haversine_km(lat_a, lng_a, lat_b, lng_b)
      radians = Math::PI / 180
      d_lat = (lat_b - lat_a) * radians
      d_lng = (lng_b - lng_a) * radians
      a = Math.sin(d_lat / 2)**2 + Math.cos(lat_a * radians) * Math.cos(lat_b * radians) * Math.sin(d_lng / 2)**2
      6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    end
end
