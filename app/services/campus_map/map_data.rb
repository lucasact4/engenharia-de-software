module CampusMap
  # Exibe apenas ocorrências no mural que tenham vínculo com um local cadastrado do campus.
  # Os pontos GPS permanecem exatos apenas quando o autor autorizou esse compartilhamento.
  class MapData
    CENTER = [ -8.0175, -34.9492 ].freeze
    BUILDING_COLORS = %w[#16a34a #f97316 #dc2626 #7c3aed #0891b2 #ca8a04 #db2777 #2563eb].freeze

    def initialize(viewer:)
      @viewer = viewer
    end

    def call
      locations = Location.active.order(:position, :name).to_a
      polygons = locations.each_with_index.filter_map do |location, index|
        next unless valid_polygon?(location.boundary)

        { boundary: location.boundary, color: BUILDING_COLORS.fetch(index % BUILDING_COLORS.size) }
      end
      posts = feed_scope.where(kind: "occurrence").where.not(alert_id: nil)
        .includes(alert: :location).order(published_at: :desc, id: :desc).limit(500)

      reports = posts.filter_map { |post| report_marker(post, locations) }
      { center: CENTER, locations: polygons, reports: reports }
    end

    private

      def feed_scope
        PublicationPolicy::FeedScope.new(@viewer, Publication.all).resolve
      end

      def report_marker(post, locations)
        alert = post.alert
        coordinates = [ alert.latitude, alert.longitude ] if alert.latitude.present? && alert.longitude.present?
        matched = locations.find { |location| coordinates && inside?(coordinates, location.boundary) }
        matched ||= alert.location if alert.location&.active?
        return unless matched

        building_point = representative_point(matched)
        return unless building_point

        exact = alert.share_exact_location? && coordinates.present? &&
          (matched.boundary.blank? || inside?(coordinates, matched.boundary))
        point = exact ? coordinates.map(&:to_f) : building_point

        {
          id: post.id,
          title: post.title,
          latitude: point[0],
          longitude: point[1],
          exact: exact,
          url: Rails.application.routes.url_helpers.publication_path(post)
        }
      end

      def representative_point(location)
        ring = location.boundary&.dig("coordinates", 0)
        if ring.is_a?(Array) && ring.size >= 4
          open_ring = ring[0...-1]
          return [ open_ring.sum { |longitude, _latitude| longitude.to_f } / open_ring.size,
                  open_ring.sum { |_longitude, latitude| latitude.to_f } / open_ring.size ].reverse
        end

        return unless location.reference_latitude.present? && location.reference_longitude.present?

        [ location.reference_latitude.to_f, location.reference_longitude.to_f ]
      end

      # `point` uses [latitude, longitude]; GeoJSON rings use [longitude, latitude].
      def inside?(point, boundary)
        ring = boundary&.dig("coordinates", 0)
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
        ring = boundary.is_a?(Hash) && boundary["type"] == "Polygon" && boundary.dig("coordinates", 0)
        ring.is_a?(Array) && ring.size >= 4
      end
  end
end
