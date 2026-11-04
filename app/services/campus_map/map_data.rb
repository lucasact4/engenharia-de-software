module CampusMap
  # Exibe ocorrências aprovadas em andamento sobre as áreas oficiais do campus.
  # Os pontos GPS permanecem exatos apenas quando o autor autorizou esse compartilhamento.
  class MapData
    CENTER = [ -8.0175, -34.9492 ].freeze
    BUILDING_COLORS = %w[#16a34a #f97316 #dc2626 #7c3aed #0891b2 #ca8a04 #db2777 #2563eb].freeze
    ACTIVE_STATUSES = %w[received triaging in_progress awaiting_information].freeze
    REPORTED_SEVERITIES = Alert.reported_severities.keys.freeze
    OFFICIAL_BUILDINGS = JSON.parse(
      Rails.root.join("public/maps/ufrpe-sede-buildings-v2.geojson").read
    ).fetch("features").freeze

    def initialize(viewer:, filters: {})
      @viewer = viewer
      @filters = filters.to_h.symbolize_keys
    end

    def call
      locations = Location.active.order(:position, :name).to_a
      polygons = locations.each_with_index.filter_map do |location, index|
        next unless valid_polygon?(location.boundary)

        { boundary: location.boundary, color: BUILDING_COLORS.fetch(index % BUILDING_COLORS.size) }
      end
      official_buildings = OFFICIAL_BUILDINGS.each_with_index.map do |feature, index|
        { id: feature.fetch("id"), geometry: feature.fetch("geometry"),
          color: BUILDING_COLORS.fetch(index % BUILDING_COLORS.size) }
      end
      posts = feed_scope.where(kind: "occurrence").where.not(alert_id: nil)
        .where(review_status: "approved")
        .where("publications.reviewed_content_version = publications.content_version")
        .where(alert_id: filtered_occurrences.select(:id))
        .includes(alert: [ :location, :category ]).order(published_at: :desc, id: :desc).limit(500)

      reports = posts.filter_map { |post| report_marker(post, locations, official_buildings) }
      spots = reports.group_by { |report| report.fetch(:spot_key) }.map do |spot_key, publications|
        spot_marker(spot_key, publications)
      end
      { center: CENTER, locations: polygons, official_buildings: official_buildings, reports: reports, spots: spots }
    end

    private

      def feed_scope
        PublicationPolicy::FeedScope.new(@viewer, Publication.all).resolve
      end

      def active_occurrences
        Alert.occurrence.where(status: ACTIVE_STATUSES)
      end

      def filtered_occurrences
        relation = active_occurrences
        relation = relation.where(category_id: @filters[:category_id]) if @filters[:category_id].present?
        relation = relation.where(status: @filters[:status]) if ACTIVE_STATUSES.include?(@filters[:status])

        severity = @filters[:severity]
        if REPORTED_SEVERITIES.include?(severity)
          relation = relation.where(reported_severity: severity)
        elsif severity == "not_reported"
          relation = relation.where(reported_severity: nil)
        end
        relation
      end

      def report_marker(post, locations, official_buildings)
        alert = post.alert
        coordinates = [ alert.latitude, alert.longitude ] if alert.latitude.present? && alert.longitude.present?
        matched = locations.find { |location| coordinates && inside?(coordinates, location.boundary) }
        matched ||= alert.location if alert.location&.active?
        matching_point = coordinates || representative_point_for_location(matched) if coordinates || matched
        official_building = official_buildings.find do |building|
          matching_point && inside?(matching_point, building.fetch(:geometry))
        end
        campus_area = matching_point && inside?(matching_point, campus_hull)
        traffic = alert.category&.code == "mobility_traffic"
        return unless matched || official_building || campus_area || (traffic && matching_point)

        place_point = if matched
          representative_point_for_location(matched) || matching_point
        elsif official_building
          representative_point_for_geometry(official_building.fetch(:geometry))
        elsif matching_point
          matching_point
        end
        return unless place_point

        exact = alert.share_exact_location? && coordinates.present? &&
          (matched.nil? || matched.boundary.blank? || inside?(coordinates, matched.boundary))
        place_type = if official_building
          "building"
        elsif traffic && !campus_area
          "traffic"
        elsif matched
          "location"
        elsif campus_area
          "campus_area"
        elsif traffic
          "traffic"
        else
          "external"
        end
        point = if exact
          coordinates.map(&:to_f)
        elsif place_type.in?(%w[building location])
          place_point
        else
          approximate_point(place_point)
        end
        spot_anchor = place_type.in?(%w[building location]) ? place_point : approximate_point(place_point)
        spot_key = case place_type
        when "building" then "official-#{official_building.fetch(:id)}"
        when "location" then "location-#{matched.id}"
        when "campus_area" then "area-#{rounded_point(matching_point).join('-')}"
        when "traffic" then "traffic-#{rounded_point(matching_point).join('-')}"
        else "external-#{rounded_point(matching_point).join('-')}"
        end

        {
          id: post.id,
          title: post.title,
          reason: alert.description.to_s.squish.truncate(280),
          category: alert.category&.name,
          place_type: place_type,
          latitude: point[0],
          longitude: point[1],
          spot_latitude: spot_anchor[0],
          spot_longitude: spot_anchor[1],
          spot_key: spot_key,
          exact: exact,
          url: Rails.application.routes.url_helpers.publication_path(post),
          google_maps_url: "https://www.google.com/maps/search/?api=1&query=#{point[0]},#{point[1]}"
        }
      end

      def approximate_point(point)
        rounded_point(point).map(&:to_f)
      end

      def rounded_point(point)
        point.map { |coordinate| coordinate.to_f.round(3) }
      end

      def spot_marker(spot_key, publications)
        single_exact_report = publications.one? && publications.first[:exact]
        point = single_exact_report ? publications.first.values_at(:latitude, :longitude) :
          publications.first.values_at(:spot_latitude, :spot_longitude)
        {
          id: spot_key,
          latitude: point[0],
          longitude: point[1],
          count: publications.size,
          place_type: publications.first.fetch(:place_type),
          google_maps_url: "https://www.google.com/maps/search/?api=1&query=#{point[0]},#{point[1]}",
          publications: publications.map do |publication|
            publication.slice(:id, :title, :reason, :category, :url, :exact, :google_maps_url)
          end
        }
      end

      def campus_hull
        @campus_hull ||= begin
          latitude_buffer = 0.0027
          longitude_buffer = latitude_buffer / Math.cos(CENTER.first * Math::PI / 180)
          points = OFFICIAL_BUILDINGS.flat_map do |feature|
            feature.dig("geometry", "coordinates", 0).flat_map do |longitude, latitude|
              [
                [ longitude - longitude_buffer, latitude - latitude_buffer ],
                [ longitude - longitude_buffer, latitude + latitude_buffer ],
                [ longitude + longitude_buffer, latitude - latitude_buffer ],
                [ longitude + longitude_buffer, latitude + latitude_buffer ]
              ]
            end
          end.uniq.sort
          lower = []
          points.each do |point|
            lower.pop while lower.size >= 2 && cross_product(lower[-2], lower[-1], point) <= 0
            lower << point
          end
          upper = []
          points.reverse_each do |point|
            upper.pop while upper.size >= 2 && cross_product(upper[-2], upper[-1], point) <= 0
            upper << point
          end
          ring = lower[0...-1] + upper[0...-1]
          ring << ring.first
          { "type" => "Polygon", "coordinates" => [ ring ] }
        end
      end

      def cross_product(origin, first, second)
        (first[0] - origin[0]) * (second[1] - origin[1]) -
          (first[1] - origin[1]) * (second[0] - origin[0])
      end

      def representative_point_for_location(location)
        ring = location.boundary&.dig("coordinates", 0)
        return representative_point_from_ring(ring) if ring.is_a?(Array) && ring.size >= 4
        return if location.reference_latitude.blank? || location.reference_longitude.blank?

        [ location.reference_latitude.to_f, location.reference_longitude.to_f ]
      end

      def representative_point_for_geometry(geometry)
        return unless geometry.is_a?(Hash) && geometry["type"] == "Polygon"

        representative_point_from_ring(geometry.dig("coordinates", 0))
      end

      def representative_point_from_ring(ring)
        if ring.is_a?(Array) && ring.size >= 4
          open_ring = ring[0...-1]
          cross_products = open_ring.each_index.map do |index|
            longitude, latitude = open_ring[index].map(&:to_f)
            next_longitude, next_latitude = open_ring[(index + 1) % open_ring.size].map(&:to_f)
            longitude * next_latitude - next_longitude * latitude
          end
          area_sum = cross_products.sum
          if area_sum.abs <= Float::EPSILON
            return [ open_ring.sum { |_longitude, latitude| latitude.to_f } / open_ring.size,
                    open_ring.sum { |longitude, _latitude| longitude.to_f } / open_ring.size ]
          end

          longitude = open_ring.each_index.sum do |index|
            current = open_ring[index].map(&:to_f)
            following = open_ring[(index + 1) % open_ring.size].map(&:to_f)
            (current[0] + following[0]) * cross_products[index]
          end / (3 * area_sum)
          latitude = open_ring.each_index.sum do |index|
            current = open_ring[index].map(&:to_f)
            following = open_ring[(index + 1) % open_ring.size].map(&:to_f)
            (current[1] + following[1]) * cross_products[index]
          end / (3 * area_sum)
          [ latitude.round(7), longitude.round(7) ]
        end
      end

      # `point` uses [latitude, longitude]; GeoJSON rings use [longitude, latitude].
      def inside?(point, boundary)
        ring = boundary&.dig("coordinates", 0)
        ring = boundary.dig("coordinates", 0, 0) if boundary.is_a?(Hash) && boundary["type"] == "MultiPolygon"
        return false unless valid_polygon?(boundary)

        latitude, longitude = point.map(&:to_f)
        inside = false
        previous = ring.last
        ring.each do |current|
          x1, y1 = previous.map(&:to_f)
          x2, y2 = current.map(&:to_f)
          crosses = (y1 > latitude) != (y2 > latitude) &&
            longitude < (x2 - x1) * (latitude - y1) / ((y2 - y1).zero? ? Float::EPSILON : (y2 - y1)) + x1
          inside = !inside if crosses
          previous = current
        end
        inside
      end

      def valid_polygon?(boundary)
        ring = if boundary.is_a?(Hash)
          case boundary["type"]
          when "Polygon" then boundary.dig("coordinates", 0)
          when "MultiPolygon" then boundary.dig("coordinates", 0, 0)
          end
        end
        ring.is_a?(Array) && ring.size >= 4
      end
  end
end
