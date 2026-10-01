require "rails_helper"

RSpec.describe Presentation do
  subject(:presentation) { described_class.load }

  let(:image_keys) { %w[imagem imagem_ampliada captura evidencia_imagem] }

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

  it "keeps the main sequence within the seven-minute limit" do
    expect(presentation.main_slides.size).to be_between(9, 11)
    expect(presentation.total_seconds).to be <= 7 * 60
  end

  it "labels main slides with numbers and appendices with letters" do
    expect(presentation.main_slides.map(&:label).first).to eq("01")
    expect(presentation.appendix_slides.map(&:label)).to eq(("A"..).first(presentation.appendix_slides.size))
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

  it "shows every table of db/schema.rb in the data model appendix" do
    tables = Rails.root.join("db/schema.rb").read.scan(/create_table "(\w+)"/).flatten
    partial = Rails.root.join("app/views/presentations/slides/_modelo_dados.html.erb").read

    tables.each do |table|
      expect(partial).to include(%(name: "#{table}")), "tabela #{table} ausente no apêndice de modelo de dados"
    end
  end
end
