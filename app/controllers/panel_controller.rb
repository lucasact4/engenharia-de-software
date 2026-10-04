# Painel inicial da área autenticada: atalhos, registros recentes e, para equipes, a fila.
class PanelController < PortalController
  def show
    authorize :panel, :show?
    user = Current.user
    @recent_alerts = policy_scope(Alert).where(author_id: user.id).includes(:category).recent_first.limit(5)
    @feed = PublicationProjection.collection(
      PublicationPolicy::FeedScope.new(user, Publication.all).resolve.order(published_at: :desc, id: :desc).limit(5), viewer: user
    )
    return unless AlertPolicy.new(user, Alert).queue?

    queue = policy_scope(Alert, policy_scope_class: AlertPolicy::HandlingScope).where.not(status: %w[resolved closed])
    @queue_counts = {
      open: queue.count,
      panic: queue.panic.count,
      unassigned: queue.where(assigned_to_id: nil).count,
      mine: queue.where(assigned_to_id: user.id).count
    }
  end
end
