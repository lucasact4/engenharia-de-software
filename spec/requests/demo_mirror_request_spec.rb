require "rails_helper"

RSpec.describe "Demo mirror", type: :request do
  it "shows the desktop, the mirrored phone and the step guide without requiring a session" do
    get demo_mirror_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("[data-controller='demo-mirror']")["data-demo-mirror-start-value"]).to eq("/")
    expect(page.css("iframe").map { |frame| frame["title"] }).to contain_exactly("SGU no computador", "SGU no celular")
    expect(page.css(".apr-mirror__shortcut").map { |button| button["data-path"] }).to include("/alertas/new", "/panico", "/atendimento")
    expect(page.css(".apr-mirror__step-title").map(&:text)).to eq(
      [ "Mural e mapa", "Registrar ocorrência", "Triagem da equipe", "Aviso e status", "Botão de pânico", "Aprovar e auditar" ]
    )
    expect(page.css("[popover].apr-mirror__pop").size).to eq(6)
    expect(page.at_css("[data-demo-mirror-target='fullscreen']")).to be_present
  end

  it "starts only on known pages of the application" do
    get demo_mirror_path(inicio: "/mural")
    expect(response.body).to include('data-demo-mirror-start-value="/mural"')

    get demo_mirror_path(inicio: "https://example.com")
    expect(response.body).to include('data-demo-mirror-start-value="/"')
  end

  it "keeps full screen and a close button in the header when embedded in the presentation" do
    get demo_mirror_path(embed: "1")

    page = Nokogiri::HTML(response.body)
    expect(page.at_css(".apr-mirror")["class"]).to include("apr-mirror--embedded")
    expect(page.at_css(".apr-mirror__back").text).to include("Voltar aos slides")
    expect(page.at_css("[data-demo-mirror-target='fullscreen']")).to be_present
    expect(page.at_css(".apr-mirror__close")["data-action"]).to eq("demo-mirror#back")
  end

  it "explains each demo step in its popover" do
    get demo_mirror_path

    popover = Nokogiri::HTML(response.body).at_css("#apr-demo-passo-3")
    expect(popover.at_css(".apr-mirror__pop-where").text).to include("logado como admin")
    expect(popover.css(".apr-mirror__pop-steps li").size).to be >= 5
    expect(popover.at_css(".apr-mirror__pop-say").text).to include("Fale:")
  end

  it "opens from the final delivery demo slide over the presentation" do
    create(:presentation_profile, delivery: "final", active: true,
      selections: { "demo" => true, "demo.roteiro" => true, "demo.acesso" => true })

    get presentation_path

    page = Nokogiri::HTML(response.body)
    launcher = page.at_css("[data-controller='demo-overlay']")
    expect(launcher.at_css("a")["href"]).to eq(demo_mirror_path(locale: nil))
    expect(launcher.at_css("dialog iframe")).to be_present
  end
end
