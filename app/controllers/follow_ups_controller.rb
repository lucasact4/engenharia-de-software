# Acompanhamentos da própria pessoa: publicações, ocorrências e perfis seguidos. São listas
# privadas filtradas pelo acesso atual. "Remover indisponíveis" apaga só vínculos próprios cujo
# alvo deixou de ser acessível, sem mostrar quais eram.
class FollowUpsController < PortalController
  PRUNE_KINDS = { "salvos" => :bookmark, "publicacoes" => :subscription, "alertas" => :alert_subscription }.freeze

  def index
    authorize :panel, :show?
    user = Current.user
    publications = SubscribedPublicationsQuery.new(user)
    @publication_cards = PublicationProjection.collection(publications.call.order(published_at: :desc).limit(50), viewer: user)
    @unavailable_publications = publications.unavailable_count
    alerts = SubscribedAlertsQuery.new(user)
    @alerts = alerts.call.includes(:category).recent_first.limit(50)
    @unavailable_alerts = alerts.unavailable_count
    @people = FollowedProfilesQuery.new(user).call.order(:display_name, :username).limit(100)
  end

  def prune
    authorize :panel, :show?
    kind = PRUNE_KINDS.fetch(params[:tipo].to_s) { raise ActiveRecord::RecordNotFound }
    removed = Social::Interactions.prune_inaccessible(actor: Current.user, kind: kind)
    target = kind == :bookmark ? saved_publications_path : follow_ups_path
    redirect_to target, notice: "#{removed} vínculo(s) indisponível(is) removido(s).", status: :see_other
  end
end
