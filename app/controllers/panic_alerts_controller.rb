# Pedido de pânico: mesma entidade Alert (kind: panic), sempre restrito e idempotente.
# Uma chave (client_request_id) por intenção confirmada; tentativas repetidas reenviam a mesma
# chave e o mesmo conteúdo. Receber o pedido não significa atendimento humano nem socorro acionado.
class PanicAlertsController < PortalController
  PANIC_FIELDS = %i[description location_id latitude longitude location_accuracy_meters
                    location_captured_at location_unavailable_reason].freeze

  def new
    authorize Alert, :create_panic?
    @client_request_id = SecureRandom.uuid
    @locations = AlertOptionsPresenter.new(actor: Current.user).locations
  end

  def create
    authorize Alert, :create_panic?
    result = Alerts::CreatePanic.call(actor: Current.user, attributes: panic_params, client_request_id: params[:client_request_id])
    message = "O sistema recebeu seu pedido (protocolo #{result.alert.protocol}). Isso não confirma que uma pessoa já viu o pedido nem que socorro foi acionado."
    respond_to do |format|
      format.html { redirect_to alert_path(result.alert), notice: message, status: :see_other }
      format.json do
        render json: { protocol: result.alert.protocol, created: result.created?, url: alert_path(result.alert), message: message },
               status: (result.created? ? :created : :ok)
      end
    end
  rescue Alerts::Create::IdempotencyConflict
    conflict = "Este pedido já foi enviado com outros dados. Confira “Meus alertas” antes de iniciar um novo pedido."
    respond_to do |format|
      format.html { render_new(conflict, :conflict) }
      format.json { render json: { error: "conflict", message: conflict, url: alerts_path }, status: :conflict }
    end
  rescue ActiveRecord::RecordInvalid => error
    respond_to do |format|
      format.html { render_new(error.record.errors.full_messages.to_sentence, :unprocessable_entity) }
      format.json { render json: { error: "invalid", message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity }
    end
  end

  private

    def render_new(message, status)
      @client_request_id = params[:client_request_id].to_s
      @locations = AlertOptionsPresenter.new(actor: Current.user).locations
      flash.now[:alert] = message
      render :new, status: status
    end

    # Localização opcional: GPS se houver coordenadas; senão o local escolhido; senão
    # indisponível com o motivo informado pelo navegador (padrão: não compartilhada).
    def panic_params
      attributes = params.fetch(:panic, {}).permit(*PANIC_FIELDS).to_h.symbolize_keys
      attributes.transform_values! { |value| value.to_s.strip.presence }
      if attributes[:latitude] || attributes[:longitude]
        attributes.merge!(location_source: "gps", location_id: nil, location_unavailable_reason: nil)
      elsif attributes[:location_id]
        attributes.merge!(location_source: "manual", latitude: nil, longitude: nil,
                          location_accuracy_meters: nil, location_captured_at: nil, location_unavailable_reason: nil)
      else
        reason = attributes[:location_unavailable_reason]
        reason = "not_shared" unless Alert.location_unavailable_reasons.key?(reason.to_s)
        attributes.merge!(location_source: "unavailable", location_id: nil, location_accuracy_meters: nil,
                          location_captured_at: nil, location_unavailable_reason: reason)
      end
      attributes.compact
    end
end
