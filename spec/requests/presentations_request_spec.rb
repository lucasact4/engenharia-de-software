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

    expect(document.at_css("#s-modelo-conceitual .apr-data-figure[data-diagram='conceptual']")).to be_present
    expect(document.at_css("#s-fluxo-ocorrencias").text).to include("Fluxo de ocorrências e emergências")
    expect(document.at_css("#s-fluxo-ocorrencias .apr-data-figure")).to be_nil
    expect(document.at_css("#s-modelo-dados").text).to include("DER físico", Presentation.schema_version)
    expect(document.at_css("#s-der-infraestrutura").text).to include("presentation_profiles", "sessões")
    expect(document.at_css("#s-modelo-dados .apr-data-legend").text).to include("0..1")
  end

  it "uses HTML and CSS for every diagram of the catalog" do
    get presentation_path

    figures = document.css(".apr-data-figure")
    expect(figures.map { |figure| figure["data-diagram"] }).to match_array(PresentationDiagram.load_all.keys)
    expect(figures.css("svg, canvas, img")).to be_empty
    expect(figures.css(".apr-data-line")).not_to be_empty
  end

  it "renders every foreign key in the detailed diagrams" do
    get presentation_path

    detailed = document.css("#s-der-operacional, #s-der-social, #s-der-infraestrutura")
    drawn = detailed.css("[data-kind='foreign_key']").map do |edge|
      [ edge["data-source"], edge["data-column"], edge["data-target"] ]
    end
    actual = ActiveRecord::Base.connection.tables.flat_map do |table|
      ActiveRecord::Base.connection.foreign_keys(table).map { |edge| [ table, edge.column.to_s, edge.to_table ] }
    end
    expect(drawn).to match_array(actual)
  end

  it "renders meeting agendas when the team supplies them" do
    presentation = Presentation.load
    presentation.gestao[:reunioes] = [
      { data: Date.new(2026, 9, 30), tipo: "Reunião de teste", pauta: [ "Revisar os requisitos" ] }
    ]
    allow(Presentation).to receive(:load).and_return(presentation)

    get presentation_path

    expect(document.at_css("#s-reunioes").text).to include("Pauta:", "Revisar os requisitos")
  end

  it "renders the real monitoring meeting with four original, accessible images" do
    get presentation_path

    slide = document.at_css("#s-reunioes")
    expect(slide.text).to include("03/10/2026", "18h20 (aproximadamente)", "Google Meet", "Funcionamento do Rails", "Encaminhamentos e responsáveis ainda precisam ser formalizados")
    expect(slide.css(".apr-figure--meeting img").size).to eq(4)
    expect(slide.css(".apr-figure--meeting img").map { |image| image["alt"] }).to all(be_present)
    expect(slide.css(".apr-figure__zoom").map { |button| button["data-zoom-src"] }).to all(include("presentation/reunioes/2026-10-03/"))
    expect(slide.text).not_to include("Nenhum registro de reunião anexado")
  end

  it "keeps the missing-evidence fallback when meeting records are removed" do
    presentation = Presentation.load
    presentation.gestao[:reunioes] = []
    allow(Presentation).to receive(:load).and_return(presentation)

    get presentation_path

    expect(document.at_css("#s-reunioes").text).to include("Nenhum registro de reunião anexado")
    expect(document.css("#s-reunioes .apr-figure--meeting")).to be_empty
  end

  describe "slide selection" do
    let(:presentation) { Presentation.load }

    def visible(selector)
      document.css(selector).reject { |node| node.has_attribute?("hidden") || node.ancestors.any? { |ancestor| ancestor.respond_to?(:has_attribute?) && ancestor.has_attribute?("hidden") } }
    end

    it "uses the catalog defaults without a saved profile and creates no records" do
      expect { get presentation_path }.not_to change(PresentationProfile, :count)

      defaults = presentation.default_selection
      expect(visible("section.apr-slide").map { |node| node["data-slide-id"] }).to eq(defaults.visible_slides.map(&:id))
      expect(document.at_css("[data-presentation-target='counter']").text).to eq("1 / #{defaults.visible_main_slides.size}")
    end

    it "marks every catalog item in the slides and nothing outside the catalog" do
      get presentation_path

      rendered = document.css("[data-apr-item]").map { |node| node["data-apr-item"] }.uniq
      expect(rendered).to match_array(presentation.items.map(&:key))
    end

    it "reflects the active profile and keeps hidden content available to the client" do
      create(:presentation_profile, :active, delivery: "primeira",
        selections: { "reunioes.registros" => false, "evolucao" => false, "requisitos" => true })

      get presentation_path

      expect(document.at_css("#s-evolucao").has_attribute?("hidden")).to be(true)
      expect(document.at_css("#s-requisitos").has_attribute?("hidden")).to be(false)
      expect(document.at_css("[data-apr-item='reunioes.registros']").has_attribute?("hidden")).to be(true)
      expect(document.at_css("#s-capa").text).to include("Primeira Entrega dos Projetos")
      expect(document.css(".apr-toc li[data-apr-slide-ref='evolucao'][hidden]")).to be_present
    end

    it "previews another saved profile with ?perfil=" do
      create(:presentation_profile, :active, selections: { "gestao" => true })
      other = create(:presentation_profile, selections: { "gestao" => false })

      get presentation_path(perfil: other.id)

      expect(document.at_css("#s-gestao").has_attribute?("hidden")).to be(true)
      expect(document.at_css(".apr-custom__profile strong").text).to eq(other.name)
    end

    it "always renders the cover and the closing slide" do
      create(:presentation_profile, :active, selections: (presentation.catalog_keys - Presentation::REQUIRED_SLIDES).index_with(false))

      get presentation_path

      expect(visible("section.apr-slide").map { |node| node["data-slide-id"] }).to eq(Presentation::REQUIRED_SLIDES)
      expect(document.at_css("[data-presentation-target='counter']").text).to eq("1 / 2")
    end

    it "renumbers the visible slides in the summary, the headings and the script" do
      create(:presentation_profile, :active, selections: { "conceito-visual" => false, "escopo" => false })

      get presentation_path

      expect(document.at_css("#s-funcionalidades .apr-kicker__num").text).to eq("02")
      expect(document.at_css(".apr-toc [data-apr-label-for='funcionalidades']").text).to eq("02")
      expect(document.at_css("#s-roteiro [data-apr-elapsed-for='problema']").text).to be_empty
    end

    it "hides empty groups instead of leaving blank columns" do
      create(:presentation_profile, :active, selections: { "gestao.trello" => false, "gestao.ambientes" => false })

      get presentation_path

      expect(document.at_css("#s-gestao [aria-labelledby='s-gestao-ambientes']").has_attribute?("hidden")).to be(true)
      expect(document.at_css("#s-gestao .apr-mgmt")["class"]).to include("apr-fit")
    end

    it "warns when the selected slides exceed the delivery time limit" do
      create(:presentation_profile, :active, selections: presentation.catalog_keys.excluding(Presentation::REQUIRED_SLIDES).index_with(true))

      get presentation_path

      expect(document.at_css("#s-roteiro .apr-estimate")["class"]).to include("is-over")
      expect(document.at_css("#s-roteiro .apr-estimate").text).to include("acima do limite de 7min")
    end

    it "offers the temporary panel without form fields that could be submitted" do
      get presentation_path

      panel = document.at_css("dialog.apr-custom")
      expect(panel.text).to include("Ajustes temporários", "Restaurar padrão do perfil")
      expect(panel.css("form, [name]")).to be_empty
      expect(panel.css("input[data-apr-toggle]").map { |input| input["data-apr-toggle"] }).to match_array(presentation.catalog_keys)
      Presentation::REQUIRED_SLIDES.each do |id|
        expect(panel.at_css("input[data-apr-toggle='#{id}']")["disabled"]).to be_present
      end
    end
  end

  it "shows each second-delivery item once in assignment order without duplicating the report" do
    get presentation_path
    expect(document.css("section.apr-slide:not([hidden])").map { |node| node["data-slide-id"] }).to eq(%w[capa conceito-visual funcionalidades retrospectiva modelo-conceitual reunioes evolucao proximos-passos status-report encerramento])
    expect(document.css("#s-evolucao .apr-timeline__title").map(&:text)).not_to include("Base Rails implantada", "Landing pública e /entrar")
    expect(document.at_css("#s-conceito-visual").text).to include("Validação da equipe pendente")
    expect(document.at_css("#s-funcionalidades [data-apr-item='funcionalidades.repositorio']").text).to include("Captura do repositório", "Abrir repositório")
    expect(document.at_css("#s-status-report").text).not_to include("Feito desde a última entrega", "Até a próxima entrega")
    expect(document.at_css("#s-status-report").text).to include("Experiência prática", "Evolução contínua", "Abrir retrospectiva", "Slide do quadro")
    expect(document.css("#s-retrospectiva [data-apr-item][hidden]").map { |node| node["data-apr-item"] }).to include("retrospectiva.licoes", "retrospectiva.acoes")
  end

  describe "requirement titles, technologies and conceptual model" do
    let(:presentation) { Presentation.load }

    it "shows the same title in the heading, counter, summary, index and panel" do
      %w[primeira segunda].each do |delivery|
        PresentationProfile.delete_all
        create(:presentation_profile, :active, delivery: delivery)
        get presentation_path
        page = Nokogiri::HTML(response.body)
        selection = PresentationProfile.last.selection(presentation)

        presentation.main_slides.reject(&:required).each do |slide|
          title = selection.slide_title(slide)
          expect(page.at_css("##{slide.dom_id}")["data-title"]).to eq(title)
          expect(page.at_css("##{slide.heading_id}").text.squish).to eq(title)
          expect(page.at_css(".apr-toc a[href='##{slide.dom_id}'] .apr-slide-list__title").text).to start_with(title)
          expect(page.at_css(".apr-index a[href='##{slide.dom_id}'] .apr-slide-list__title").text).to start_with(title)
          expect(page.at_css(".apr-custom input[data-apr-toggle='#{slide.id}']").parent.text.squish).to eq(title)
        end
      end
    end

    it "names the second delivery slides after the assignment and marks the requirement apart from the slide number" do
      create(:presentation_profile, :active, delivery: "segunda")
      get presentation_path

      expect(document.at_css("#s-conceito-visual .apr-title").text).to eq("Protótipo com o conceito visual do projeto")
      expect(document.at_css("#s-conceito-visual .apr-requirement").text).to eq("2ª entrega · Item 1")
      expect(document.at_css("#s-conceito-visual .apr-kicker__num").text).to match(/\A\d{2}\z/)
      expect(document.at_css("#s-reunioes .apr-title").text).to eq("Evidência de reuniões de monitoramento do projeto")
      expect(document.at_css("#s-gestao .apr-requirement").text).to eq("Complementar")
      expect(document.at_css("#s-checklist").text).to include("Item 2", "GitHub criado e estruturado com código fonte total ou parcial")
    end

    it "explains in the panel that a checkbox means display, not completion, and that Concluir does not save" do
      get presentation_path

      note = document.at_css(".apr-custom__note").text.squish
      expect(note).to include("Marcado = exibir", "Não significa que a exigência foi concluída", "não são salvos", "Concluir fecha o painel sem salvar")
    end

    it "renders technology cards with stored logos, neutral symbols and versions from the real sources" do
      get presentation_path

      cards = document.css("#s-arquitetura .apr-tech__card")
      expect(cards.size).to eq(presentation.tecnologias[:stack].sum { |group| group[:itens].size })
      expect(cards.map { |card| card.at_css(".apr-tech__name").text }).to include("Ruby", "Ruby on Rails", "SQLite", "Pundit")
      expect(document.css("#s-arquitetura .apr-tech__img").map { |img| img["src"] }).to all(start_with("/assets/presentation/logos/"))
      expect(document.css("#s-arquitetura img[src^='http']")).to be_empty
      versions = document.css("#s-arquitetura [data-apr-item='arquitetura.versoes'].apr-tech__versions").map(&:text).join(" ")
      expect(versions).to include(Rails.version, SQLite3::SQLITE_VERSION, "sem versão única")
      expect(document.at_css("#s-arquitetura .apr-tech__toggle")["aria-expanded"]).to eq("false")
      document.css("#s-arquitetura .apr-tech__item").each do |trigger|
        expect(document.at_css("##{trigger['aria-describedby']}")).to be_present
      end
    end

    it "hides the version button and numbers when Versões is unchecked" do
      create(:presentation_profile, :active, selections: { "arquitetura.versoes" => false })
      get presentation_path

      expect(document.at_css("#s-arquitetura .apr-tech__toggle").has_attribute?("hidden")).to be(true)
      expect(document.css("#s-arquitetura .apr-tech__versions").map { |node| node.has_attribute?("hidden") }).to all(be(true))
    end

    it "shows the native conceptual model with separate production, review and assumptions" do
      get presentation_path

      slide = document.at_css("#s-modelo-conceitual")
      expect(slide.at_css("[data-apr-item='modelo-conceitual.diagrama'] .apr-data-figure[data-diagram='conceptual']")).to be_present
      status = slide.at_css("[data-apr-item='modelo-conceitual.situacao']").text.squish
      expect(status).to include("Diagrama produzido", "Implementado", "Revisão da equipe", "Aguardando evidência", "Premissas de requisitos", "Aguardando decisão")
      expect(slide.text).not_to include("ainda não há tabela", "não anexado")
    end

    it "lists presentation_profiles as support in the infrastructure DER, outside the conceptual model" do
      get presentation_path

      expect(document.at_css("#s-der-infraestrutura [data-table='presentation_profiles']")).to be_present
      expect(document.at_css("#s-modelo-conceitual").text).not_to include("presentation_profiles")
    end
  end
end
