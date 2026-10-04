# frozen_string_literal: true

# Ocorrências e pânicos na administração. Não usa o CRUD genérico: criação, correção,
# atendimento, audiência e restrição passam pelos services, cada um com sua query de policy.
# Não há exclusão: o registro é encerrado com motivo (Transition) e permanece no histórico.
class Admin::AlertsController < Admin::ApplicationController
  include ErrorResponses
  include AlertFormParams
  include AlertHandlingActions
  include AlertQueueFilters

  before_action :set_alert, except: %i[index new create]

  def index
    authorize Alert, :index?
    scope = apply_queue_filters(policy_scope(Alert))
    @pagy, @alerts = pagy(scope.includes(:category, :location, :assigned_to, :author), limit: 20)
    @filter_options = queue_filter_options
    @assignees = User.active.where(admin: true)
      .or(User.active.where(id: UserRole.joins(:role).where(roles: { code: %w[coordination security] }).select(:user_id)))
      .order(:email_address)
  end

  def show
    authorize @alert, :show?
    render_handling_show(:ok)
  end

  # O administrador registra como autor de si mesmo; não há criação "em nome de" outra pessoa.
  def new
    authorize Alert, :create_occurrence?
    @alert = Alert.new(kind: "occurrence", requested_visibility: "restricted", location_source: Location.active.exists? ? "manual" : "gps")
    @client_request_id = SecureRandom.uuid
    @options = AlertOptionsPresenter.new(actor: Current.user)
  end

  def create
    authorize Alert, :create_occurrence?
    @client_request_id = params[:client_request_id].to_s
    result = Alerts::CreateOccurrence.call(actor: Current.user, attributes: occurrence_params, photos: uploaded_photos,
                                           client_request_id: @client_request_id)
    redirect_to admin_alert_path(result.alert), status: :see_other,
                flash: { success: "Ocorrência registrada com o protocolo #{result.alert.protocol}." }
  rescue ActiveRecord::RecordInvalid, Alerts::Create::IdempotencyConflict => error
    @alert = Alert.new(occurrence_params.merge(kind: "occurrence"))
    if error.is_a?(ActiveRecord::RecordInvalid)
      error.record.errors.each { |item| @alert.errors.import(item) }
    else
      @alert.errors.add(:base, "Este envio já foi usado com outros dados; confira a lista antes de registrar de novo.")
    end
    @photos_dropped = uploaded_photos.any?
    @options = AlertOptionsPresenter.new(actor: Current.user)
    render :new, status: (error.is_a?(Alerts::Create::IdempotencyConflict) ? :conflict : :unprocessable_entity)
  end

  # Correção administrativa (texto e categoria), com motivo e auditoria.
  def edit
    authorize @alert, :correct_content?
    @options = AlertOptionsPresenter.new(actor: Current.user, alert: @alert)
  end

  def update
    authorize @alert, :correct_content?
    Alerts::CorrectContent.call(actor: Current.user, alert: @alert, attributes: correction_params,
                                reason: params[:reason], lock_version: lock_version_param)
    redirect_to admin_alert_path(@alert), flash: { success: "Correção registrada no histórico." }, status: :see_other
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => error
    errors = @alert.errors.dup
    reload_alert
    @alert.assign_attributes(correction_params)
    errors.each { |item| @alert.errors.import(item) }
    flash.now[:alert] = stale_conflict_message if error.is_a?(ActiveRecord::StaleObjectError)
    @options = AlertOptionsPresenter.new(actor: Current.user, alert: @alert)
    render :edit, status: (error.is_a?(ActiveRecord::StaleObjectError) ? :conflict : :unprocessable_entity)
  end

  # Ampliar a audiência ou liberar o bloqueio exige motivo; a publicação vinculada é
  # reavaliada (retirada ou revisão invalidada) pelo próprio service.
  def audience
    authorize @alert, :change_audience?
    run_handling(:audience, params.permit(:requested_visibility, :reason).to_h) do
      Alerts::ChangeAudience.call(actor: Current.user, alert: @alert, requested_visibility: params[:requested_visibility],
                                  reason: params[:reason], lock_version: params[:lock_version])
    end
  end

  def restriction
    authorize @alert, :restrict?
    run_handling(:restriction, params.permit(:reason).to_h) do
      Alerts::Restrict.call(actor: Current.user, alert: @alert, reason: params[:reason], lock_version: params[:lock_version])
    end
  end

  private

    def set_alert
      @alert = policy_scope(Alert).find(params[:id])
    end

    def handling_show_path(alert)
      admin_alert_path(alert)
    end

    def render_handling_show(status)
      @detail = AlertDetailPresenter.new(@alert, viewer: Current.user)
      @options = AlertOptionsPresenter.new(actor: Current.user, alert: @alert)
      @assignees = EligibleAssigneesQuery.new(@alert).call
      @publication = @alert.publication
      @publishable = @alert.occurrence? && @publication.nil? &&
        (Publication.compatible_sources_for("internal").or(Publication.compatible_sources_for("public_external"))).exists?(@alert.id)
      render :show, status: status
    end

    def error_layout
      "admin/base"
    end
end
