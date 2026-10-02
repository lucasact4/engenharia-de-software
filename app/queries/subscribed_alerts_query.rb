# Alertas acompanhados pela pessoa, filtrados pelo acesso atual (AlertPolicy::Scope).
class SubscribedAlertsQuery
  def initialize(viewer)
    @viewer = viewer
  end

  def call
    return Alert.none unless @viewer&.active?

    relation = Alert.where(id: @viewer.alert_subscriptions.select(:alert_id))
    AlertPolicy::Scope.new(@viewer, relation).resolve
  end
end
