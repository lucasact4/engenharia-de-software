# Conteúdo da apresentação, lido de config/presentation/*.yml.
# O roteiro.yml também define o catálogo de slides e conteúdos configuráveis; a escolha do que
# aparece em cada ocasião fica nos perfis salvos no banco (PresentationProfile) e é resolvida
# por Presentation::Selection.
class Presentation
  CONTENT_DIR = Rails.root.join("config/presentation")
  SECTIONS = %w[
    entrega roteiro requisitos evolucao conceito_visual funcionalidades
    diagramas tecnologias gestao retrospectiva planejamento
  ].freeze

  # Sempre visíveis, em qualquer perfil e no ajuste temporário.
  REQUIRED_SLIDES = %w[capa encerramento].freeze

  IDENTIFIER = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  REQUIRED_KEYS = {
    "entrega" => %w[projeto equipe links entregas entrega_padrao],
    "roteiro" => %w[slides],
    "requisitos" => %w[problema publico fluxo_valor dimensoes conflitos documento requisitos_refinados card_refinamento regra_dimensoes],
    "evolucao" => %w[marcos capacidades observacoes],
    "conceito_visual" => %w[capturas paleta prototipo],
    "funcionalidades" => %w[criterios itens],
    "diagramas" => %w[itens],
    "tecnologias" => %w[stack mudancas],
    "gestao" => %w[cards ambientes praticas reunioes],
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

  REQUIREMENT_GROUPS = { "item" => "Item", "status_report" => "Status report", "condicao" => "Condição" }.freeze

  Item = Struct.new(:key, :id, :slide_id, :title, :default, :parent_key, :legacy_keys, keyword_init: true)

  # Exigência acadêmica de uma entrega (entrega.yml → exigencias): fonte central dos nomes.
  Requirement = Struct.new(:number, :group, :text, :slides, :state, :note, :confirmed, :delivery, keyword_init: true) do
    def title = text.to_s.sub(/\.\z/, "")
    def slide_ids = slides.map { |slide| slide[:id] }
    def title_for(slide_id) = slides.find { |slide| slide[:id] == slide_id }&.dig(:titulo).presence || title

    # "Item 1", "Status report", "Condição".
    def part = group == "item" ? "Item #{number}" : REQUIREMENT_GROUPS.fetch(group)
  end

  Slide = Struct.new(:id, :title, :seconds, :presenter, :appendix, :dark, :default, :required, :items, :legacy_keys, keyword_init: true) do
    def partial = "presentations/slides/#{id.tr('-', '_')}"
    def dom_id = "s-#{id}"
    def heading_id = "#{dom_id}-titulo"
    def item_key(item_id) = "#{id}.#{item_id}"
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

  def self.schema_version
    Rails.root.join("db/schema.rb").read[/define\(version: ([\d_]+)\)/, 1]
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
    @slides ||= roteiro.fetch(:slides).map do |entry|
      required = REQUIRED_SLIDES.include?(entry[:id])

      Slide.new(
        id: entry[:id],
        title: entry[:titulo],
        seconds: entry[:tempo].to_i,
        presenter: entry[:responsavel].presence,
        appendix: entry[:apendice] == true,
        dark: entry[:tema] == "escuro",
        default: required || entry[:padrao],
        required: required,
        legacy_keys: Array(entry[:substitui]),
        items: Array(entry[:conteudos]).map do |content|
          Item.new(
            key: "#{entry[:id]}.#{content[:id]}",
            id: content[:id],
            slide_id: entry[:id],
            title: content[:titulo],
            default: content[:padrao],
            parent_key: content[:dentro_de].presence && "#{entry[:id]}.#{content[:dentro_de]}",
            legacy_keys: Array(content[:substitui])
          )
        end
      ).freeze
    end
  end

  def main_slides(delivery = default_delivery) = ordered_slides(delivery).reject(&:appendix)
  def appendix_slides = slides.select(&:appendix)

  def academic_slide_ids(delivery)
    requirements(delivery).flat_map(&:slide_ids).uniq.select { |id| !slide(id).appendix }
  end

  # A ordem do enunciado vale para a página, seleção, índice, formulário e impressão.
  def ordered_slides(delivery)
    academic = academic_slide_ids(delivery)
    extras = slides.reject { |slide| slide.appendix || slide.required || academic.include?(slide.id) }
    [ slide("capa"), *academic.map { |id| slide(id) }, *extras, slide("encerramento"), *appendix_slides ]
  end

  def slide_groups(delivery)
    academic = academic_slide_ids(delivery)
    [
      [ "principal", "Roteiro da entrega (na ordem do enunciado)", [ slide("capa"), *academic.map { |id| slide(id) }, slide("encerramento") ] ],
      [ "complementar", "Complementares opcionais (fora do roteiro recomendado)", slides.reject { |slide| slide.appendix || slide.required || academic.include?(slide.id) } ],
      [ "apendice", "Apêndices opcionais (entram no PDF quando marcados)", appendix_slides ]
    ]
  end

  def slide(id)
    slides.find { |slide| slide.id == id }
  end

  def items
    @items ||= slides.flat_map(&:items)
  end

  def item(key)
    items_by_key[key]
  end

  # Todas as chaves que um perfil pode guardar: ids dos slides e "<slide>.<conteúdo>".
  def catalog_keys
    @catalog_keys ||= slides.map(&:id) + items.map(&:key)
  end

  def catalog_key?(key)
    catalog_keys.include?(key.to_s)
  end

  def deliveries
    entrega.fetch(:entregas)
  end

  def delivery(id)
    deliveries.find { |delivery| delivery[:id] == id.to_s }
  end

  def default_delivery
    delivery(entrega[:entrega_padrao])
  end

  # Exigências da entrega, na ordem do enunciado.
  def requirements(delivery)
    Array(delivery[:exigencias]).map do |entry|
      Requirement.new(
        number: entry[:numero], group: entry[:grupo], text: entry[:texto], slides: Array(entry[:slides]),
        state: entry[:estado], note: entry[:observacao], confirmed: entry[:confirmado_pela_equipe] == true,
        delivery: delivery
      )
    end
  end

  def slide_requirements(slide, delivery)
    requirements(delivery).select { |requirement| requirement.slide_ids.include?(slide.id) }
  end

  # Título exibido em todos os lugares (cabeçalho, índice, contador, admin e painel): o texto
  # da exigência que o slide atende nesta entrega; sem exigência, o titulo do roteiro.yml.
  def slide_title(slide, delivery)
    slide_requirements(slide, delivery).first&.title_for(slide.id) || slide.title
  end

  # Identificação discreta, separada do número do slide: "2ª entrega · Item 1",
  # "2ª entrega · Item 3 · Status report"; slides sem exigência são complementares.
  def slide_label(slide, delivery)
    parts = slide_requirements(slide, delivery).map(&:part).uniq
    return "#{delivery[:rotulo]} · #{parts.join(' · ')}" if parts.any?
    return if slide.required

    slide.appendix ? "Apêndice · complementar" : "Complementar"
  end

  # Seleção padrão do roteiro (nenhum perfil salvo).
  def default_selection
    Selection.new(self)
  end

  def schema_version = self.class.schema_version

  REPOSITORY_FOLDERS = [
    [ "app/models", "app/models/**/*.rb", "models e concerns" ],
    [ "app/controllers", "app/controllers/**/*.rb", "controllers" ],
    [ "app/services", "app/services/**/*.rb", "serviços do domínio" ],
    [ "app/policies", "app/policies/*.rb", "políticas de acesso (Pundit)" ],
    [ "app/views", "app/views/**/*.erb", "templates ERB" ],
    [ "db/migrate", "db/migrate/*.rb", "migrações" ],
    [ "spec", "spec/**/*_spec.rb", "arquivos de teste (RSpec)" ]
  ].freeze

  # Estrutura lida do próprio repositório: contagens de arquivos e jobs do workflow de CI.
  def repository_overview
    @repository_overview ||= begin
      workflow = Rails.root.join(".github/workflows/ci.yml")
      jobs = workflow.exist? ? (YAML.safe_load_file(workflow, aliases: true) || {}).fetch("jobs", {}).keys : []
      {
        folders: REPOSITORY_FOLDERS.map do |path, pattern, label|
          { path: path, label: label, count: Dir.glob(Rails.root.join(pattern)).size }
        end,
        ci_jobs: jobs
      }
    end
  end

  def version_for(item)
    return RUBY_VERSION if item[:versao_ruby]
    return item[:versao] if item[:versao].present?

    self.class.locked_gem_versions[item[:gem]] if item[:gem].present?
  end

  VERSION_SOURCES = %w[gem ruby_version_file sqlite_engine texto].freeze

  # Versões de um card de tecnologia, cada uma lida da fonte declarada em tecnologias.yml:
  # Gemfile.lock, .ruby-version, biblioteca SQLite carregada ou texto honesto (sem número).
  def versions_for(item)
    Array(item[:versoes]).map do |entry|
      value, source = if entry[:gem].present?
        [ self.class.locked_gem_versions[entry[:gem]], "Gemfile.lock" ]
      elsif entry[:ruby_version_file]
        [ Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-"), ".ruby-version" ]
      elsif entry[:sqlite_engine]
        [ SQLite3::SQLITE_VERSION, "biblioteca carregada" ]
      else
        [ nil, nil ]
      end
      { label: entry[:rotulo], value: value, text: entry[:texto], source: source }
    end
  end

  # Todos os estados usados no conteúdo, para validação e resumo.
  def states_in_use
    collect_states(@data).uniq
  end

  private

    def items_by_key
      @items_by_key ||= items.index_by(&:key)
    end

    def validate!
      REQUIRED_KEYS.each do |section, keys|
        content = @data.fetch(section)
        missing = keys.reject { |key| content.key?(key) }
        raise ArgumentError, "#{section}.yml: chaves ausentes: #{missing.join(', ')}" if missing.any?
      end

      validate_slides!
      validate_deliveries!
      validate_stack!

      unknown = states_in_use - STATES.keys
      raise ArgumentError, "Estados desconhecidos: #{unknown.join(', ')}" if unknown.any?

      unless conceito_visual.fetch(:paleta).all? { |color| color[:hex].to_s.match?(/\A#[0-9a-f]{6}\z/i) }
        raise ArgumentError, "conceito_visual.yml: cada cor deve ser hexadecimal de seis dígitos (#RRGGBB)."
      end
    end

    def validate_slides!
      entries = roteiro.fetch(:slides)
      unless entries.is_a?(Array) && entries.any? && entries.all? { |entry| entry.is_a?(Hash) }
        raise ArgumentError, "roteiro.yml: slides deve ser uma lista não vazia de mapas."
      end

      entries.each do |entry|
        valid_id = entry[:id].is_a?(String) && entry[:id].match?(IDENTIFIER)
        valid_time = entry[:apendice] == true || (entry[:tempo].is_a?(Integer) && entry[:tempo] >= 0)
        unless valid_id && entry[:titulo].is_a?(String) && entry[:titulo].present? && valid_time
          raise ArgumentError, "roteiro.yml: slide precisa de id válido, título e tempo inteiro não negativo."
        end

        unless REQUIRED_SLIDES.include?(entry[:id]) || [ true, false ].include?(entry[:padrao])
          raise ArgumentError, "roteiro.yml: o slide #{entry[:id]} precisa de padrao: true ou false."
        end

        validate_contents!(entry)
      end

      if entries.map { |entry| entry[:id] }.uniq.size != entries.size
        raise ArgumentError, "roteiro.yml: ids de slides devem ser únicos."
      end

      REQUIRED_SLIDES.each do |id|
        entry = entries.find { |candidate| candidate[:id] == id }
        if entry.nil? || entry[:apendice] == true
          raise ArgumentError, "roteiro.yml: o slide obrigatório #{id} precisa existir fora dos apêndices."
        end
      end
    end

    def validate_contents!(entry)
      contents = entry[:conteudos]
      return if contents.nil?

      unless contents.is_a?(Array) && contents.all? { |content| content.is_a?(Hash) }
        raise ArgumentError, "roteiro.yml: conteudos do slide #{entry[:id]} deve ser uma lista de mapas."
      end

      seen = []
      contents.each do |content|
        valid = content[:id].is_a?(String) && content[:id].match?(IDENTIFIER) &&
          content[:titulo].is_a?(String) && content[:titulo].present? &&
          [ true, false ].include?(content[:padrao]) &&
          (content[:dentro_de].blank? || seen.include?(content[:dentro_de]))
        unless valid && seen.exclude?(content[:id])
          raise ArgumentError, "roteiro.yml: conteúdo inválido no slide #{entry[:id]} " \
            "(id único, título, padrao true/false e dentro_de apontando para um conteúdo anterior)."
        end

        seen << content[:id]
      end
    end

    def validate_deliveries!
      list = entrega.fetch(:entregas)
      unless list.is_a?(Array) && list.any? && list.all? { |delivery| delivery.is_a?(Hash) }
        raise ArgumentError, "entrega.yml: entregas deve ser uma lista não vazia de mapas."
      end

      ids = list.map { |delivery| delivery[:id] }
      unless ids.all? { |id| id.is_a?(String) && id.match?(IDENTIFIER) } && ids.uniq.size == ids.size
        raise ArgumentError, "entrega.yml: cada entrega precisa de um id único (letras minúsculas, números e hífens)."
      end

      slide_ids = roteiro.fetch(:slides).map { |entry| entry[:id] }
      list.each do |delivery|
        limit = delivery[:duracao_maxima_minutos]
        unless delivery[:titulo].present? && (limit.nil? || (limit.is_a?(Integer) && limit.positive?))
          raise ArgumentError, "entrega.yml: a entrega #{delivery[:id]} precisa de título e duracao_maxima_minutos inteiro (ou vazio)."
        end

        validate_requirements!(delivery, slide_ids)
      end

      unless ids.include?(entrega[:entrega_padrao])
        raise ArgumentError, "entrega.yml: entrega_padrao deve ser o id de uma das entregas."
      end
    end

    def validate_requirements!(delivery, slide_ids)
      list = delivery[:exigencias]
      unless list.is_a?(Array) && list.all? { |entry| entry.is_a?(Hash) }
        raise ArgumentError, "entrega.yml: exigencias da entrega #{delivery[:id]} deve ser uma lista de mapas."
      end

      list.each do |entry|
        slides = entry[:slides]
        valid = entry[:texto].is_a?(String) && entry[:texto].present? &&
          REQUIREMENT_GROUPS.key?(entry[:grupo]) &&
          (entry[:grupo] != "item" || (entry[:numero].is_a?(Integer) && entry[:numero].positive?)) &&
          slides.is_a?(Array) && slides.any? && slides.all? { |slide| slide.is_a?(Hash) && slide[:id].is_a?(String) }
        raise ArgumentError, "entrega.yml: exigência inválida na entrega #{delivery[:id]}: #{entry[:texto].inspect}" unless valid

        unknown = slides.map { |slide| slide[:id] } - slide_ids
        raise ArgumentError, "entrega.yml: exigência aponta para slides inexistentes: #{unknown.join(', ')}" if unknown.any?
      end
    end

    # Cada tecnologia precisa de nome, logo (com fonte e licença) ou símbolo neutro e versões
    # com exatamente uma fonte. Número digitado à mão não é aceito: use gem, arquivo ou texto.
    def validate_stack!
      tecnologias.fetch(:stack).flat_map { |group| group.fetch(:itens) }.each do |item|
        logo = item[:logo]
        visual = logo.is_a?(Hash) ? logo[:arquivo].present? && logo[:fonte].present? && logo[:licenca].present? : item[:simbolo].present?
        versions = Array(item[:versoes])
        sources_ok = versions.all? do |entry|
          entry[:rotulo].present? && VERSION_SOURCES.count { |source| entry[source].present? } == 1
        end
        unless item[:nome].present? && visual && versions.any? && sources_ok && !item.key?(:versao)
          raise ArgumentError, "tecnologias.yml: #{item[:nome].inspect} precisa de logo (arquivo, fonte, licença) " \
            "ou simbolo e de versoes com rotulo e uma única fonte (gem, ruby_version_file, sqlite_engine ou texto)."
        end
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
