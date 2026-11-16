# RF011: o pedido de pânico aciona todos os agentes de segurança ativos e todos os administradores.
# A proximidade não exclui ninguém: com GPS do pedido e posições recentes, só define a ordem de envio
# (os agentes mais próximos recebem primeiro).
class PanicRecipientsQuery
  def initialize(alert)
    @alert = alert
  end

  def call
    eligible = EligibleAssigneesQuery.new(@alert).call
    return eligible unless @alert.latitude.present? && @alert.longitude.present?

    distances = SecurityPresence.fresh.where(user_id: eligible.map(&:id)).to_h do |presence|
      [ presence.user_id, distance_km(@alert.latitude, @alert.longitude, presence.latitude, presence.longitude) ]
    end
    eligible.each_with_index.sort_by { |user, index| [ distances.fetch(user.id, Float::INFINITY), index ] }.map(&:first)
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
