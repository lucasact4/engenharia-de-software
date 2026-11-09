module Notifications
  module Nearby
    OPEN_STATUSES = %w[received triaging in_progress awaiting_information].freeze
    RADIUS_METERS = 500

    module_function

    def publish(publication)
      return unless publication.occurrence? && publication.published?
      return unless publication.saved_changes.keys.intersect?(%w[state visibility review_status content_version])

      point = publication_point(publication)
      return unless point && OPEN_STATUSES.include?(publication.alert.status)

      locations = selectable_locations.select { |location| within_radius?(location, point) }
      return if locations.empty?

      users = NotificationPreference.where(location: locations).where.not(user_id: publication.author_id).select(:user_id)
      User.active.where(id: users).find_each do |user|
        next unless PublicationPolicy::FeedScope.new(user, Publication.all).resolve.exists?(publication.id)

        Notification.create_or_find_by!(user: user, event_key: "nearby:#{publication.id}") do |notification|
          notification.assign_attributes(kind: "nearby_alert", publication: publication, message: "Há uma ocorrência perto do local que você acompanha.")
        end
      end
    end

    def selectable_locations
      Location.active.where.not(reference_latitude: nil).where.not(reference_longitude: nil)
    end

    def current_match?(notification)
      location = NotificationPreference.find_by(user_id: notification.user_id)&.location
      publication = notification.publication
      point = publication_point(publication)
      location&.active? && point && OPEN_STATUSES.include?(publication.alert.status) && within_radius?(location, point)
    end

    def publication_point(publication)
      alert = publication&.alert
      return unless alert&.occurrence?
      return [ alert.latitude, alert.longitude ] if alert.share_exact_location? && alert.latitude && alert.longitude

      location = alert.location
      [ location.reference_latitude, location.reference_longitude ] if location&.active? && location.reference_latitude && location.reference_longitude
    end

    def within_radius?(location, point)
      return false unless location.reference_latitude && location.reference_longitude

      lat1, lon1, lat2, lon2 = [ location.reference_latitude, location.reference_longitude, *point ].map { |degrees| degrees.to_f * Math::PI / 180 }
      haversine = Math.sin((lat2 - lat1) / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin((lon2 - lon1) / 2)**2
      12_742_000 * Math.asin(Math.sqrt(haversine.clamp(0, 1))) <= RADIUS_METERS
    end
  end
end
