class NearbyAlertNotificationJob < ApplicationJob
  EARTH_RADIUS_KM = 6371.0

  def perform(alert_id)
    alert = Alert.includes(:location, :publication).find_by(id: alert_id)
    return unless public_geolocated_alert?(alert)

    User.active.where(email_notifications_enabled: true, nearby_alerts_email_enabled: true)
      .includes(:notification_location).find_each do |user|
      location = user.notification_location
      next unless user.email_notifications_consented? && location&.active? && location.reference_latitude && location.reference_longitude
      alert_latitude, alert_longitude = alert_coordinates(alert)
      next unless alert_latitude && alert_longitude
      next if distance_km(alert_latitude, alert_longitude, location.reference_latitude, location.reference_longitude) > user.nearby_alerts_radius_km

      AlertNotificationsMailer.nearby(user, alert).deliver_now
    end
  end

  private

    def public_geolocated_alert?(alert)
      alert&.occurrence? && alert.publication&.published? && alert.publication.public_external? && !alert.publication.expired? &&
        alert_coordinates(alert).all?(&:present?)
    end

    def alert_coordinates(alert)
      return [ alert.latitude, alert.longitude ] if alert.latitude.present? && alert.longitude.present?

      [ alert.location&.reference_latitude, alert.location&.reference_longitude ]
    end

    def distance_km(lat1, lon1, lat2, lon2)
      radians = Math::PI / 180
      dlat = (lat2.to_f - lat1.to_f) * radians
      dlon = (lon2.to_f - lon1.to_f) * radians
      a = Math.sin(dlat / 2)**2 + Math.cos(lat1.to_f * radians) * Math.cos(lat2.to_f * radians) * Math.sin(dlon / 2)**2
      2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(a))
    end
end
