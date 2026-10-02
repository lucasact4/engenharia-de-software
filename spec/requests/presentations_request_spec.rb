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

  it "renders meeting agendas when the team supplies them" do
    presentation = Presentation.load
    presentation.gestao[:reunioes] = [
      { data: Date.new(2026, 9, 30), tipo: "Reunião de teste", pauta: [ "Revisar os requisitos" ] }
    ]
    allow(Presentation).to receive(:load).and_return(presentation)

    get presentation_path

    expect(document.at_css("#s-gestao").text).to include("Pauta:", "Revisar os requisitos")
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
        selections: { "gestao.reunioes" => false, "evolucao" => false, "requisitos" => true })

      get presentation_path

      expect(document.at_css("#s-evolucao").has_attribute?("hidden")).to be(true)
      expect(document.at_css("#s-requisitos").has_attribute?("hidden")).to be(false)
      expect(document.at_css("[data-apr-item='gestao.reunioes']").has_attribute?("hidden")).to be(true)
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
      create(:presentation_profile, :active, selections: { "problema" => false, "escopo" => false })

      get presentation_path

      expect(document.at_css("#s-evolucao .apr-kicker__num").text).to eq("02")
      expect(document.at_css(".apr-toc [data-apr-label-for='evolucao']").text).to eq("02")
      expect(document.at_css("#s-roteiro [data-apr-elapsed-for='problema']").text).to be_empty
    end

    it "hides empty groups instead of leaving blank columns" do
      create(:presentation_profile, :active, selections: { "gestao.trello" => false, "gestao.cards" => false, "gestao.ambientes" => false })

      get presentation_path

      expect(document.at_css("#s-gestao [aria-labelledby='s-gestao-trello']").has_attribute?("hidden")).to be(true)
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
end
