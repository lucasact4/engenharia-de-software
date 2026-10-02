require "rails_helper"

RSpec.describe "Presentation", type: :request do
  let(:document) { Nokogiri::HTML(response.body) }

  it "renders the presentation without authentication" do
    get presentation_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sistema de Gerenciamento Urbano")
    expect(document.css("section.apr-slide").size).to eq(Presentation.load.slides.size)
  end

  it "keeps every link public or inside the application" do
    get presentation_path

    hrefs = document.css("a[href]").map { |link| link["href"] }

    expect(hrefs).to all(match(%r{\A(https://|/|#s-|#apr-)}))
    expect(hrefs.grep(%r{\A(file:|[A-Za-z]:\\|\\\\|/mnt/|/home/)|wsl\.localhost}i)).to be_empty
  end

  it "points internal slide links to existing slides" do
    get presentation_path

    ids = document.css("section.apr-slide").map { |section| section["id"] }
    targets = document.css("a[href^='#s-']").map { |link| link["href"].delete_prefix("#") }.uniq

    expect(targets - ids).to be_empty
  end

  it "opens external links in a new tab without exposing the opener" do
    get presentation_path

    document.css("a[href^='https://']").each do |link|
      expect(link["target"]).to eq("_blank")
      expect(link["rel"]).to include("noopener")
    end
  end

  it "draws only real tables and columns in the DER and covers every column in the detailed appendices" do
    get presentation_path

    connection = ActiveRecord::Base.connection
    schema_tables = connection.tables - %w[schema_migrations ar_internal_metadata]
    drawn = Hash.new { |hash, key| hash[key] = [] }

    document.css(".apr-er__table[data-table]").each do |group|
      table = group["data-table"]
      columns = group.css(".apr-er__col").map(&:text)
      expect(schema_tables).to include(table)
      expect(columns - connection.columns(table).map(&:name)).to be_empty, "colunas inexistentes em #{table}"
      drawn[table].concat(columns) unless group.ancestors("#s-modelo-dados").any?
    end

    schema_tables.each do |table|
      expect(drawn[table]).to match_array(connection.columns(table).map(&:name)), "colunas de #{table} incompletas no DER"
    end
  end

  it "keeps the conceptual model, the physical DER and the flow as distinct artifacts" do
    get presentation_path

    diagrams = document.at_css("#s-diagramas")
    expect(diagrams.at_css("img[src*='modelo-conceitual']")).to be_present
    expect(diagrams.text).to include("Fluxo de ocorrências e emergências")
    expect(document.at_css("#s-modelo-dados").text).to include("DER físico", Presentation.schema_version)
    expect(document.at_css("#s-der-infraestrutura").text).to include("dogs", "preservado")
    expect(document.at_css("#s-modelo-dados svg desc").text).to include("0..1")
  end

  it "renders meeting agendas when the team supplies them" do
    presentation = Presentation.load
    presentation.gestao[:reunioes] = [
      { data: Date.new(2026, 9, 30), tipo: "Reunião de teste", pauta: [ "Revisar os requisitos" ] }
    ]
    allow(Presentation).to receive(:load).and_return(presentation)

    get presentation_path

    expect(document.at_css("#s-gestao").text).to include("Pauta:", "Revisar os requisitos")
  end
end
