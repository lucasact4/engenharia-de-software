# Área autenticada de ocorrências: registrar, consultar os próprios registros, ler ocorrências
# internas, editar o próprio relato enquanto permitido e restringir a própria audiência.
# O atendimento fica em Handling::AlertsController; a administração, em Admin::AlertsController.
class AlertsController < PortalController
  include AlertFormParams

  TABS = %w[meus internos acompanhados].freeze

  before_action :set_alert, only: %i[show edit update audience]

  def index
    authorize Alert, :index?
    @tab = TABS.include?(params[:aba]) ? params[:aba] : "meus"
    scope = case @tab
    when "meus" then policy_scope(Alert).where(author_id: Current.user.id)
    when "internos" then policy_scope(Alert).occurrence.where(visibility: "internal").where.not(author_id: Current.user.id)
    else SubscribedAlertsQuery.new(Current.user).call
    end
    scope = filter(scope)
    @unavailable_subscriptions = SubscribedAlertsQuery.new(Current.user).unavailable_count if @tab == "acompanhados"
    @pagy, @alerts = pagy(scope.includes(:category, :location).recent_first, limit: 15)
  end

  def show
    authorize @alert, :show?
    @detail = AlertDetailPresenter.new(@alert, viewer: Current.user)
    @subscribed = Current.user.alert_subscriptions.exists?(alert_id: @alert.id)
  end

  def new
    authorize Alert, :create_occurrence?
    @alert = Alert.new(kind: "occurrence", requested_visibility: "restricted", location_source: default_location_source)
    @client_request_id = SecureRandom.uuid
    prepare_form
  end

  def create
    authorize Alert, :create_occurrence?
    @client_request_id = requested_client_request_id
    result = Alerts::CreateOccurrence.call(
      actor: Current.user, attributes: occurrence_params, photos: uploaded_photos, client_request_id: @client_request_id
    )
    message = result.created? ? "Ocorrência registrada. Protocolo #{result.alert.protocol}." : "Este envio já tinha sido recebido (protocolo #{result.alert.protocol}); nada foi duplicado."
    redirect_to alert_path(result.alert), notice: message, status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    rebuild_form(error.record)
    render :new, status: :unprocessable_entity
  rescue Alerts::Create::IdempotencyConflict
    rebuild_form(nil)
    @idempotency_conflict = true
    @conflict = Current.user.authored_alerts.find_by(client_request_id: @client_request_id.downcase)
    render :new, status: :conflict
  end

  def edit
    authorize @alert, :update_content?
    prepare_form
  end

  def update
    authorize @alert, :update_content?
    Alerts::UpdateContent.call(
      actor: Current.user, alert: @alert, attributes: occurrence_params(with_visibility: false),
      photos: uploaded_photos, lock_version: lock_version_param
    )
    redirect_to alert_path(@alert), notice: "Relato atualizado.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    keep_errors_and_reload { @alert.assign_attributes(occurrence_params(with_visibility: false)) }
    prepare_form
    render :edit, status: :unprocessable_entity
  rescue ActiveRecord::StaleObjectError
    submitted = occurrence_params(with_visibility: false)
    @alert = policy_scope(Alert).find(@alert.id)
    unless policy(@alert).update_content?
      return redirect_to alert_path(@alert), status: :see_other,
                         alert: "O registro mudou de situação enquanto você editava e não pode mais ser editado."
    end

    @stale_conflict = true
    @alert.assign_attributes(submitted)
    flash.now[:alert] = stale_conflict_message
    prepare_form
    render :edit, status: :conflict
  end

  # O autor só pode restringir o próprio registro; ampliar a audiência é administrativo.
  def audience
    authorize @alert, :change_audience?
    Alerts::ChangeAudience.call(actor: Current.user, alert: @alert, requested_visibility: "restricted",
                                lock_version: params[:lock_version])
    redirect_to alert_path(@alert), notice: "Registro restrito a você e à equipe responsável.", status: :see_other
  rescue ActiveRecord::StaleObjectError
    redirect_to alert_path(@alert), alert: stale_conflict_message, status: :see_other
  end

  private

    def set_alert
      @alert = policy_scope(Alert).find(params[:id])
    end

    def filter(scope)
      scope = scope.where(status: params[:status]) if Alert.statuses.key?(params[:status].to_s)
      scope.text_search(params[:q], "alerts.protocol", "alerts.title")
    end

    # Após um conflito 409, só uma escolha explícita ("é uma nova ocorrência") troca a chave;
    # a chave substituta veio no formulário e se repete em novas tentativas do mesmo envio.
    def requested_client_request_id
      replacement = params[:replacement_client_request_id].to_s
      return replacement if params[:new_intent] == "1" && replacement.match?(Alerts::Create::UUID_FORMAT)

      params[:client_request_id].to_s
    end

    def default_location_source
      Location.active.exists? ? "manual" : "gps"
    end

    def prepare_form
      @options = AlertOptionsPresenter.new(actor: Current.user, alert: @alert.persisted? ? @alert : nil)
      @detail = AlertDetailPresenter.new(@alert, viewer: Current.user) if @alert.persisted?
    end

    # Reconstrói o formulário com o que a pessoa enviou; as fotos precisam ser escolhidas de novo.
    def rebuild_form(record)
      @alert = Alert.new(occurrence_params.merge(kind: "occurrence"))
      record&.errors&.each { |error| @alert.errors.import(error) }
      @photos_dropped = uploaded_photos.any?
      prepare_form
    end

    def keep_errors_and_reload
      errors = @alert.errors.dup
      @alert = policy_scope(Alert).find(@alert.id)
      yield
      errors.each { |error| @alert.errors.import(error) }
      @photos_dropped = uploaded_photos.any?
    end
end
