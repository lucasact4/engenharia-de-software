# Conteúdo da apresentação da segunda entrega, lido de config/presentation/*.yml.
# Não usa banco de dados nem serviços externos.
class Presentation
  CONTENT_DIR = Rails.root.join("config/presentation")
  SECTIONS = %w[
    entrega roteiro requisitos evolucao conceito_visual funcionalidades
    diagramas tecnologias gestao retrospectiva planejamento
  ].freeze

  REQUIRED_KEYS = {
    "entrega" => %w[projeto equipe checklist links],
    "roteiro" => %w[slides],
    "requisitos" => %w[problema publico fluxo_valor dimensoes conflitos documento requisitos_selecionados card_refinamento regra_dimensoes],
    "evolucao" => %w[marcos capacidades observacoes],
    "conceito_visual" => %w[capturas paleta],
    "funcionalidades" => %w[criterios itens],
    "diagramas" => %w[itens],
    "tecnologias" => %w[stack mudancas],
    "gestao" => %w[cards praticas reunioes],
    "retrospectiva" => %w[pontos acoes licoes],
    "planejamento" => %w[marco proximos_passos riscos dependencias]
  }.freeze

  STATES = {
    "implementado" => "Implementado",
    "parcial" => "Parcialmente implementado",
    "planejado" => "Planejado",
    "aguardando_decisao" => "Aguardando decisão",
    "aguardando_evidencia" => "Aguardando evidência"
  }.freeze

  Slide = Struct.new(:id, :title, :seconds, :presenter, :appendix, :dark, :label, keyword_init: true) do
    def partial = "presentations/slides/#{id.tr('-', '_')}"
    def dom_id = "s-#{id}"
    def heading_id = "#{dom_id}-titulo"
  end

  SECTIONS.each do |section|
    define_method(section) { @data.fetch(section) }
  end

  def self.load
    data = SECTIONS.index_with do |section|
      content = YAML.safe_load_file(CONTENT_DIR.join("#{section}.yml"), permitted_classes: [ Date ]) || {}
      raise ArgumentError, "#{section}.yml deve conter um mapa de chaves e valores." unless content.is_a?(Hash)

      ActiveSupport::HashWithIndifferentAccess.new(content)
    end

    new(data)
  end

  def self.locked_gem_versions
    @locked_gem_versions ||= Bundler::LockfileParser
      .new(Bundler.read_file(Bundler.default_lockfile))
      .specs
      .each_with_object({}) { |spec, versions| versions[spec.name] ||= spec.version.to_s }
  end

  def initialize(data)
    @data = data
    validate!
  end

  def slides
    @slides ||= begin
      main_number = 0
      appendix_letter = "A"

      roteiro.fetch(:slides).map do |slide|
        appendix = slide[:apendice] == true

        if appendix
          label = appendix_letter
          appendix_letter = appendix_letter.succ
        else
          main_number += 1
          label = format("%02d", main_number)
        end

        Slide.new(
          id: slide.fetch(:id),
          title: slide.fetch(:titulo),
          seconds: slide[:tempo].to_i,
          presenter: slide[:responsavel].presence,
          appendix: appendix,
          dark: slide[:tema] == "escuro",
          label: label
        )
      end
    end
  end

  def main_slides = slides.reject(&:appendix)
  def appendix_slides = slides.select(&:appendix)

  def slide(id)
    slides.find { |slide| slide.id == id }
  end

  def total_seconds
    main_slides.sum(&:seconds)
  end

  def version_for(item)
    return RUBY_VERSION if item[:versao_ruby]
    return item[:versao] if item[:versao].present?

    self.class.locked_gem_versions[item[:gem]] if item[:gem].present?
  end

  # Todos os estados usados no conteúdo, para validação e resumo.
  def states_in_use
    collect_states(@data).uniq
  end

  private

    def validate!
      REQUIRED_KEYS.each do |section, keys|
        content = @data.fetch(section)
        missing = keys.reject { |key| content.key?(key) }
        raise ArgumentError, "#{section}.yml: chaves ausentes: #{missing.join(', ')}" if missing.any?
      end

      entries = roteiro.fetch(:slides)
      unless entries.is_a?(Array) && entries.any? && entries.all? { |entry| entry.is_a?(Hash) }
        raise ArgumentError, "roteiro.yml: slides deve ser uma lista não vazia de mapas."
      end

      entries.each do |entry|
        valid_id = entry[:id].is_a?(String) && entry[:id].match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
        valid_time = entry[:apendice] == true || (entry[:tempo].is_a?(Integer) && entry[:tempo] >= 0)
        unless valid_id && entry[:titulo].is_a?(String) && entry[:titulo].present? && valid_time
          raise ArgumentError, "roteiro.yml: slide precisa de id válido, título e tempo inteiro não negativo."
        end
      end
      if entries.map { |entry| entry[:id] }.uniq.size != entries.size
        raise ArgumentError, "roteiro.yml: ids de slides devem ser únicos."
      end

      unknown = states_in_use - STATES.keys
      raise ArgumentError, "Estados desconhecidos: #{unknown.join(', ')}" if unknown.any?

      unless conceito_visual.fetch(:paleta).all? { |color| color[:hex].to_s.match?(/\A#[0-9a-f]{6}\z/i) }
        raise ArgumentError, "conceito_visual.yml: cada cor deve ser hexadecimal de seis dígitos (#RRGGBB)."
      end
    end

    def collect_states(value)
      case value
      when Hash then value.flat_map { |key, nested| key.to_s == "estado" ? [ nested ] : collect_states(nested) }
      when Array then value.flat_map { |nested| collect_states(nested) }
      else []
      end
    end
end
