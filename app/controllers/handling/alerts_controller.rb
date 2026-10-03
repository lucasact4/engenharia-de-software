# Fila de atendimento para coordenação, segurança e administração. Lista e abre somente o que
# a pessoa pode atender (AlertPolicy::HandlingScope), sem acesso ao restante da administração.
class Handling::AlertsController < PortalController
  include AlertHandlingActions
  include AlertQueueFilters

  before_action :set_alert, except: :index

  def index
    authorize Alert, :queue?
    scope = policy_scope(Alert, policy_scope_class: AlertPolicy::HandlingScope)
    scope = apply_queue_filters(scope, default_open: true)
    @pagy, @alerts = pagy(scope.includes(:category, :location, :assigned_to), limit: 20)
    @filter_options = queue_filter_options
  end

  def show
    authorize @alert, :handle?
    render_handling_show(:ok)
  end

  private

    def set_alert
      @alert = policy_scope(Alert, policy_scope_class: AlertPolicy::HandlingScope).find(params[:id])
    end

    def handling_show_path(alert)
      handling_alert_path(alert)
    end

    def render_handling_show(status)
      @detail = AlertDetailPresenter.new(@alert, viewer: Current.user)
      @options = AlertOptionsPresenter.new(actor: Current.user, alert: @alert)
      @assignees = EligibleAssigneesQuery.new(@alert).call
      render :show, status: status
    end
end
