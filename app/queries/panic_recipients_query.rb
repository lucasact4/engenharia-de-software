# Prioriza até três pessoas de segurança mais próximas com GPS recente; sem coordenadas
# confiáveis, aciona todos os destinatários elegíveis como contingência.
class PanicRecipientsQuery
  MAX_NEARBY_RECIPIENTS = 3

  def initialize(alert)
    @alert = alert
  end

  def call
    eligible = EligibleAssigneesQuery.new(@alert).call.to_a
    return eligible unless @alert.latitude.present? && @alert.longitude.present?

    presences = SecurityPresence.fresh.includes(:user)
      .where(user_id: eligible.map(&:id))
      .select { |presence| presence.user.role?(:security) }
    return eligible if presences.empty?

    nearby = presences.sort_by do |presence|
      distance_km(@alert.latitude, @alert.longitude, presence.latitude, presence.longitude)
    end.first(MAX_NEARBY_RECIPIENTS).map(&:user)

    admins = eligible.select(&:admin?)
    (nearby + admins).uniq
  end

  private

    def distance_km(latitude_a, longitude_a, latitude_b, longitude_b)
      radians = Math::PI / 180
      lat_delta = (latitude_b.to_f - latitude_a.to_f) * radians
      lon_delta = (longitude_b.to_f - longitude_a.to_f) * radians
      a = Math.sin(lat_delta / 2)**2 + Math.cos(latitude_a.to_f * radians) *
        Math.cos(latitude_b.to_f * radians) * Math.sin(lon_delta / 2)**2
      6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    end
end
