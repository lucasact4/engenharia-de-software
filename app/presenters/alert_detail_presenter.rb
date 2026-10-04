# Decide o que cada leitor vê de um alerta. Autor e quem atende recebem autoria, coordenadas,
# fotos e histórico completo; leitores de ocorrência interna veem só o relato, a categoria,
# o local do catálogo e as mudanças de situação, sem notas, motivos ou identidades.
class AlertDetailPresenter
  HISTORY_TITLES = {
    "alert.created" => "Registro recebido pelo sistema",
    "alert.content_updated" => "Relato editado pelo autor",
    "alert.content_corrected" => "Relato corrigido pela administração",
    "alert.status_changed" => "Situação alterada",
    "alert.assessed" => "Classificação do atendimento atualizada",
    "alert.assigned" => "Responsável alterado",
    "alert.audience_changed" => "Audiência alterada",
    "alert.restricted" => "Registro restrito e divulgação bloqueada",
    "alert.photo_removed" => "Foto removida"
  }.freeze

  READER_ACTIONS = %w[alert.created alert.status_changed].freeze

  attr_reader :alert, :viewer

  def initialize(alert, viewer:)
    @alert = alert
    @viewer = viewer
  end

  def policy
    @policy ||= AlertPolicy.new(viewer, alert)
  end

  def author?
    viewer.present? && alert.author_id == viewer.id
  end

  def operational?
    policy.show_operational_details?
  end

  def handler?
    policy.handle?
  end

  def photos
    return [] unless policy.show_photos?

    alert.ordered_photos
  end

  def author_label
    return "Você" if author?
    return unless handler?

    author = alert.author
    [ author.display_name, author.email_address ].compact_blank.uniq.join(" · ")
  end

  def assignee_label
    return unless operational?
    return "Sem responsável" if alert.assigned_to.nil?

    alert.assigned_to.display_name.presence || alert.assigned_to.email_address
  end

  def location_label
    case alert.location_source
    when "manual" then alert.location&.name || alert.location_description
    when "map" then operational? ? "Ponto selecionado no mapa" : "Informada no mapa (coordenadas restritas)"
    when "gps" then operational? ? "GPS do aparelho" : "Informada por GPS (coordenadas restritas)"
    else I18n.t("enums.alert.location_source.unavailable.label")
    end
  end

  def coordinates
    return unless operational? && (alert.location_gps? || alert.location_map?)

    { latitude: alert.latitude, longitude: alert.longitude, accuracy: alert.location_accuracy_meters,
      captured_at: alert.location_captured_at }
  end

  def history
    events = AuditEvent.for_subject(alert).includes(:actor).order(:created_at, :id)
    events = events.where(action: READER_ACTIONS) unless operational?
    events.map { |event| history_entry(event) }
  end

  private

    def history_entry(event)
      {
        at: event.created_at,
        title: HISTORY_TITLES.fetch(event.action, event.action),
        details: history_details(event),
        actor: (handler? ? actor_label(event.actor) : nil),
        reason: (handler? || (author? && event.action == "alert.status_changed") ? event.reason : nil)
      }
    end

    def history_details(event)
      changes = event.changeset
      details = []
      if (status = changes["status"])
        details << "#{status_label(status.first)} → #{status_label(status.last)}"
        details << "Reabertura" if event.metadata["reopening"]
      end
      return details unless operational?

      if (closure = changes["closure_reason"]) && closure.last
        details << "Motivo: #{I18n.t("enums.alert.closure_reason.#{closure.last}.label")}"
      end
      if (priority = changes["priority"])
        details << "Prioridade: #{enum_or_blank('priority', priority.last)}"
      end
      if (severity = changes["assessed_severity"])
        details << "Severidade avaliada: #{enum_or_blank('severity', severity.last)}"
      end
      if (audience = changes["requested_visibility"])
        details << "Audiência solicitada: #{enum_or_blank('requested_visibility', audience.last)}"
      end
      details << "Responsável atualizado" if changes.key?("assigned_to_id") && handler?
      fields = Array(event.metadata["fields"])
      details << "Campos: #{fields.map { |field| Alert.human_attribute_name(field) }.join(', ')}" if fields.any?
      details << "Fotos restantes: #{event.metadata['photos_count']}" if event.action == "alert.photo_removed"
      details
    end

    def status_label(value)
      value.present? ? I18n.t("enums.alert.status.#{value}.label") : "—"
    end

    def enum_or_blank(scope, value)
      value.present? ? I18n.t("enums.alert.#{scope}.#{value}.label") : "não classificada"
    end

    def actor_label(actor)
      return "Sistema" if actor.nil?

      actor.display_name.presence || actor.email_address
    end
end
