# Acompanhar/deixar de acompanhar o atendimento de uma ocorrência acessível (POST/DELETE explícitos).
# Deixar de acompanhar funciona mesmo depois de perder o acesso e não revela o alerta.
class AlertSubscriptionsController < PortalController
  def create
    alert = policy_scope(Alert).find(params[:alert_id])
    authorize alert, :subscribe?
    Social::Interactions.subscribe_alert(actor: Current.user, alert: alert)
    redirect_to alert_path(alert), notice: "Você está acompanhando este atendimento nesta página e em Acompanhamentos.", status: :see_other
  end

  def destroy
    skip_authorization # remove apenas o vínculo da própria sessão (Social::Interactions)
    Social::Interactions.unsubscribe_alert(actor: Current.user, alert: Alert.new(id: params[:alert_id].to_i))
    alert = policy_scope(Alert).find_by(id: params[:alert_id])
    redirect_to (alert ? alert_path(alert) : follow_ups_path), notice: "Acompanhamento removido.", status: :see_other
  end
end
