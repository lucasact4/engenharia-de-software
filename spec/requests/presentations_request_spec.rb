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
end
