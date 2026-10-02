require "rails_helper"

RSpec.describe Presentation do
  subject(:presentation) { described_class.load }

  let(:image_keys) { %w[imagem imagem_ampliada captura evidencia_imagem arquivo] }

  def string_values(value, key = nil, &block)
    case value
    when Hash then value.each { |nested_key, nested| string_values(nested, nested_key.to_s, &block) }
    when Array then value.each { |nested| string_values(nested, key, &block) }
    when String then yield(key, value)
    end
  end

  def all_content
    Presentation::SECTIONS.map { |section| presentation.public_send(section) }
  end

  def content_data
    Presentation::SECTIONS.index_with { |section| presentation.public_send(section).deep_dup }
  end

  it "reports missing content keys before rendering" do
    data = content_data
    data.fetch("gestao").delete("reunioes")

    expect { described_class.new(data) }.to raise_error(ArgumentError, /gestao.yml.*reunioes/)
  end

  it "rejects duplicate slide identifiers" do
    data = content_data
    data.fetch("roteiro")[:slides].last[:id] = data.fetch("roteiro")[:slides].first[:id]

    expect { described_class.new(data) }.to raise_error(ArgumentError, /ids de slides devem ser únicos/)
  end

  it "rejects malformed slide identifiers and durations" do
    [ { id: "../../layout" }, { tempo: "quarenta" } ].each do |attributes|
      data = content_data
      data.fetch("roteiro")[:slides].first.merge!(attributes)

      expect { described_class.new(data) }.to raise_error(ArgumentError, /slide precisa/)
    end
  end

  it "rejects arbitrary CSS values in the palette" do
    data = content_data
    data.fetch("conceito_visual")[:paleta].first[:hex] = "url(https://example.com/image)"

    expect { described_class.new(data) }.to raise_error(ArgumentError, /cada cor deve ser hexadecimal/)
  end

  it "rejects unknown states before rendering" do
    data = content_data
    data.fetch("gestao")[:cards].first[:estado] = "concluido"

    expect { described_class.new(data) }.to raise_error(ArgumentError, /Estados desconhecidos: concluido/)
  end

  it "requires the cover and the closing slide outside the appendices" do
    data = content_data
    data.fetch("roteiro")[:slides].reject! { |slide| slide[:id] == "encerramento" }

    expect { described_class.new(data) }.to raise_error(ArgumentError, /obrigatório encerramento/)
  end

  it "requires an explicit default for every optional slide" do
    data = content_data
    data.fetch("roteiro")[:slides].find { |slide| slide[:id] == "gestao" }.delete(:padrao)

    expect { described_class.new(data) }.to raise_error(ArgumentError, /gestao precisa de padrao/)
  end

  it "rejects malformed or duplicated contents in the catalog" do
    [
      { id: "Cards", titulo: "Inválido", padrao: true },
      { id: "cards", titulo: "Duplicado", padrao: true },
      { id: "extra", titulo: "Sem padrão" },
      { id: "filho", titulo: "Pai ausente", padrao: true, dentro_de: "inexistente" }
    ].each do |content|
      data = content_data
      data.fetch("roteiro")[:slides].find { |slide| slide[:id] == "gestao" }[:conteudos] << content

      expect { described_class.new(data) }.to raise_error(ArgumentError, /conteúdo inválido no slide gestao/)
    end
  end

  it "builds stable item keys from the slide and content ids" do
    expect(presentation.catalog_keys).to include("gestao", "reunioes.registros", "retrospectiva.imagem", "arquitetura.versoes")
    expect(presentation.item("arquitetura.versoes").parent_key).to eq("arquitetura.tecnologias")
  end

  it "validates deliveries and their requirements" do
    data = content_data
    data.fetch("entrega")[:entregas].first[:exigencias].first[:slides] = [ { id: "slide-inexistente" } ]
    expect { described_class.new(data) }.to raise_error(ArgumentError, /slides inexistentes/)

    data = content_data
    data.fetch("entrega")[:entregas].first[:exigencias].first.delete(:numero)
    expect { described_class.new(data) }.to raise_error(ArgumentError, /exigência inválida/)

    data = content_data
    data.fetch("entrega")[:entrega_padrao] = "terceira"
    expect { described_class.new(data) }.to raise_error(ArgumentError, /entrega_padrao/)
  end

  it "covers the subjects of both academic deliveries" do
    first = presentation.requirements(presentation.delivery("primeira"))
    second = presentation.requirements(presentation.delivery("segunda"))

    expect(first.select { |item| item.group == "item" }.map(&:number)).to eq((1..6).to_a)
    expect(second.select { |item| item.group == "item" }.map(&:number)).to eq((1..5).to_a)
    expect(second.count { |item| item.group == "status_report" }).to eq(3)
    expect((first + second).flat_map(&:slide_ids)).to all(satisfy { |id| presentation.slide(id) })
    expect(presentation.delivery("segunda")[:duracao_maxima_minutos]).to eq(7)
  end

  it "has a partial for every slide" do
    presentation.slides.each do |slide|
      path = Rails.root.join("app/views", "#{slide.partial.sub(%r{([^/]+)\z}, '_\1')}.html.erb")

      expect(path).to exist, "partial ausente para o slide #{slide.id}"
    end
  end

  it "uses only the documented states" do
    expect(presentation.states_in_use - Presentation::STATES.keys).to be_empty
  end

  it "references only images that exist in app/assets/images" do
    all_content.each do |content|
      string_values(content) do |key, value|
        next unless image_keys.include?(key)

        expect(Rails.root.join("app/assets/images", value)).to exist, "imagem ausente: #{value}"
      end
    end
  end

  it "does not publish local Windows or WSL paths" do
    all_content.each do |content|
      string_values(content) do |_key, value|
        expect(value).not_to match(%r{\A([A-Za-z]:\\|\\\\|/mnt/|/home/|file:)|wsl\.localhost}i)
      end
    end
  end

  it "reads stack versions from the lockfile" do
    expect(presentation.version_for({ gem: "rails" })).to eq(Rails.version)
    expect(presentation.version_for({ versao_ruby: true })).to eq(RUBY_VERSION)
  end

  it "shows every table of db/schema.rb in the DER appendices" do
    tables = Rails.root.join("db/schema.rb").read.scan(/create_table "(\w+)"/).flatten
    drawn = PresentationDiagram.load_all.values.flat_map do |diagram|
      diagram.nodes.filter_map { |node| node["table"] unless node["reference"] }
    end.uniq
    expect(drawn).to match_array(tables)
  end

  it "stamps the DER with the current schema version" do
    expect(presentation.schema_version).to eq(ActiveRecord::Base.connection_pool.migration_context.current_version.to_s.sub(/\A(\d{4})(\d{2})(\d{2})(\d{6})\z/, '\1_\2_\3_\4'))
  end

  describe "titles from the delivery requirements" do
    let(:first) { presentation.delivery("primeira") }
    let(:second) { presentation.delivery("segunda") }

    it "uses the requirement text as the slide title in each delivery" do
      presentation.deliveries.each do |delivery|
        presentation.requirements(delivery).each do |requirement|
          requirement.slides.each do |entry|
            slide = presentation.slide(entry[:id])
            next unless presentation.slide_requirements(slide, delivery).first == requirement

            expected = entry[:titulo].presence || requirement.text.delete_suffix(".")
            expect(presentation.slide_title(slide, delivery)).to eq(expected)
          end
        end
      end

      expect(presentation.slide_title(presentation.slide("conceito-visual"), second)).to eq("Protótipo com o conceito visual do projeto")
      expect(presentation.slide_title(presentation.slide("arquitetura"), first)).to eq("Lista de ferramentas e tecnologias escolhidas")
      expect(presentation.slide_title(presentation.slide("gestao"), first)).to eq("Ferramenta de monitoramento dos projetos ativa com os requisitos e links para ambientes — Trello")
      expect(presentation.slide_title(presentation.slide("proximos-passos"), first)).to eq("Planejamento dos próximos passos do projeto")
      expect(presentation.slide_title(presentation.slide("proximos-passos"), second)).to eq("O que será feito até a próxima entrega")
    end

    it "separates the requirement number from the slide number" do
      expect(presentation.slide_label(presentation.slide("requisitos"), first)).to eq("1ª entrega · Item 1")
      expect(presentation.slide_label(presentation.slide("funcionalidades"), second)).to eq("2ª entrega · Item 2")
      expect(presentation.slide_label(presentation.slide("funcionalidades"), second)).to eq("2ª entrega · Item 2")
      expect(presentation.slide_label(presentation.slide("retrospectiva"), second)).to eq("2ª entrega · Item 3")
      expect(presentation.slide_label(presentation.slide("gestao"), second)).to eq("Complementar")
      expect(presentation.slide_label(presentation.slide("modelo-dados"), second)).to eq("Apêndice · complementar")
      expect(presentation.slide_label(presentation.slide("capa"), second)).to be_nil
    end

    it "keeps each requirement of the second delivery in its own slide, apart from Trello" do
      ids = presentation.requirements(second).select { |item| item.group == "item" }.to_h { |item| [ item.number, item.slide_ids ] }

      expect(ids).to eq(1 => [ "conceito-visual" ], 2 => [ "funcionalidades" ], 3 => [ "retrospectiva" ], 4 => [ "modelo-conceitual" ], 5 => [ "reunioes" ])
      expect(ids.values.flatten).not_to include("gestao")
    end
  end

  describe "technology cards" do
    def item(name)
      presentation.tecnologias[:stack].flat_map { |group| group[:itens] }.find { |entry| entry[:nome] == name }
    end

    it "reads versions from the real sources and separates integration gems from the underlying technology" do
      locked = described_class.locked_gem_versions

      expect(presentation.versions_for(item("Ruby on Rails"))).to eq([ { label: "gem rails", value: Rails.version, text: nil, source: "Gemfile.lock" } ])
      expect(presentation.versions_for(item("Ruby")).first[:value]).to eq(Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-"))
      sqlite = presentation.versions_for(item("SQLite"))
      expect(sqlite.map { |version| version[:value] }).to eq([ locked.fetch("sqlite3"), SQLite3::SQLITE_VERSION ])
      tailwind = presentation.versions_for(item("Tailwind CSS"))
      expect(tailwind.map { |version| version[:value] }).to eq([ locked.fetch("tailwindcss-rails"), locked.fetch("tailwindcss-ruby") ])
      expect(presentation.versions_for(item("GitHub Actions")).first).to include(value: nil, text: a_string_including("sem versão única"))
    end

    it "rejects hand-typed versions and logos without source and license" do
      data = content_data
      data.fetch("tecnologias")[:stack].first[:itens].first[:versao] = "3.4.8"
      expect { described_class.new(data) }.to raise_error(ArgumentError, /tecnologias.yml/)

      data = content_data
      data.fetch("tecnologias")[:stack].first[:itens].first[:logo].delete(:licenca)
      expect { described_class.new(data) }.to raise_error(ArgumentError, /tecnologias.yml/)
    end

    it "stores every logo in the project and keeps a neutral symbol for tools without a verifiable logo" do
      items = presentation.tecnologias[:stack].flat_map { |group| group[:itens] }

      items.select { |entry| entry[:logo] }.each do |entry|
        expect(Rails.root.join("app/assets/images", entry.dig(:logo, :arquivo))).to exist
      end
      expect(items.select { |entry| entry[:simbolo] }.map { |entry| entry[:nome] }).to include("Pundit", "bcrypt", "Importmap", "RSpec", "Brakeman", "Dev Container")
    end
  end

  it "counts the repository structure from the real folders and CI workflow" do
    overview = presentation.repository_overview

    expect(overview[:folders].find { |folder| folder[:path] == "db/migrate" }[:count]).to eq(Dir.glob(Rails.root.join("db/migrate/*.rb")).size)
    expect(overview[:folders].map { |folder| folder[:count] }).to all(be_positive)
    expect(overview[:ci_jobs]).to include("test", "lint")
  end
end
