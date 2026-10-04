# Opções de formulário vindas dos catálogos, enums e permissões do usuário.
class AlertOptionsPresenter
  def initialize(actor:, alert: nil)
    @actor = actor
    @alert = alert
  end

  def kinds
    Alert.kinds.values.map { |value| SelectOption.from_enum("alert.kind", value) }
  end

  # Ativas em ordem; uma categoria inativa já associada aparece como indisponível.
  def categories
    catalog_options(Category, @alert&.category)
  end

  # Categorias cujo detalhamento é obrigatório (ex.: "Outro"); o servidor valida de novo.
  def category_ids_requiring_details
    Category.where(requires_details: true).pluck(:id)
  end

  CATEGORY_EXAMPLES = {
    "infrastructure" => "Lâmpada apagada, rampa danificada ou infiltração no prédio.",
    "security" => "Ameaça, furto ou situação suspeita. Em risco imediato, use o canal de emergência.",
    "climate_environment" => "Alagamento, galho com risco de queda ou descarte ambiental inadequado.",
    "mobility_traffic" => "Via bloqueada, estacionamento irregular ou dificuldade na circulação.",
    "services_utilities" => "Falta de água, queda de energia ou internet indisponível.",
    "cleaning_sanitation" => "Acúmulo de lixo, vazamento de esgoto ou banheiro sem limpeza.",
    "other" => "Situação que não se encaixa nas demais opções; descreva o assunto no detalhamento."
  }.freeze

  def category_guidance
    entries = Category.active.ordered.to_a
    entries << @alert.category if @alert&.category && !@alert.category.active?
    entries.map do |entry|
      { title: entry.name, text: entry.description.presence || "Selecione quando o assunto corresponder a esta categoria.",
        example: CATEGORY_EXAMPLES.fetch(entry.code, "Descreva a situação e indique o impacto observado no campus.") }
    end
  end

  def locations
    catalog_options(Location, @alert&.location)
  end

  def location_sources(kind: current_kind)
    values = Alert.location_sources.values
    values -= %w[unavailable] if kind == "occurrence"
    values.map { |value| SelectOption.from_enum("alert.location_source", value) }
  end

  def location_unavailable_reasons(kind: current_kind)
    return [] unless kind == "panic"

    Alert.location_unavailable_reasons.values.map { |value| SelectOption.from_enum("alert.location_unavailable_reason", value) }
  end

  def requested_visibilities(kind: current_kind)
    values = kind == "panic" ? %w[restricted] : Alert.requested_visibilities.values
    values.map { |value| SelectOption.from_enum("alert.requested_visibility", value) }
  end

  def reported_severities
    severity_options
  end

  def assessed_severities
    assess? ? severity_options : []
  end

  def priorities
    return [] unless assess?

    Alert.priorities.values.map { |value| SelectOption.from_enum("alert.priority", value) }
  end

  def statuses
    Alert.statuses.values.map { |value| SelectOption.from_enum("alert.status", value) }
  end

  def transitions
    return [] unless @alert && policy.transition?

    Alert.allowed_transitions_from(@alert.status).filter_map do |target|
      next if @alert.closed? && !policy.reopen_closed?

      SelectOption.from_enum("alert.status", target)
    end
  end

  def closure_reasons
    return [] unless @alert && policy.transition?

    values = @alert.resolved? ? %w[resolved] : Alert.closure_reasons.values - %w[resolved]
    values.map { |value| SelectOption.from_enum("alert.closure_reason", value) }
  end

  def to_h
    {
      kinds: kinds, categories: categories, locations: locations, location_sources: location_sources,
      location_unavailable_reasons: location_unavailable_reasons, requested_visibilities: requested_visibilities,
      reported_severities: reported_severities, assessed_severities: assessed_severities, priorities: priorities,
      statuses: statuses, transitions: transitions, closure_reasons: closure_reasons
    }.transform_values { |options| options.map(&:to_h) }
  end

  private

    def current_kind
      @alert&.kind || "occurrence"
    end

    def policy
      @policy ||= AlertPolicy.new(@actor, @alert)
    end

    def assess?
      @alert.present? && policy.assess?
    end

    def severity_options
      Alert::SEVERITIES.values.map { |value| SelectOption.from_enum("alert.severity", value) }
    end

    def catalog_options(model, current)
      entries = model.active.ordered.to_a
      entries << current if current && !current.active?
      entries.map { |entry| SelectOption.from_catalog(entry) }
    end
end
