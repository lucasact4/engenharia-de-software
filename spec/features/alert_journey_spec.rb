require "rails_helper"

# Jornada 1: uma pessoa registra a ocorrência, a coordenação atende e resolve, e o autor
# acompanha a situação, sem ver notas internas. Inclui GPS simulado e o fallback manual.
RSpec.describe "Occurrence journey", type: :feature, js: true do
  let!(:category) { create(:category, name: "Iluminação") }
  let(:author) { create(:user, email_address: "autora@example.com") }
  let(:coordinator) { create(:user, email_address: "coordenacao@example.com").tap { |user| grant_role(user, :coordination) } }

  def mock_geolocation(result)
    script = case result
    when :success
      "navigator.geolocation.getCurrentPosition = (ok) => setTimeout(() => ok({ coords: { latitude: -8.0171234, longitude: -34.9501234, accuracy: 18 }, timestamp: Date.now() }), 50)"
    when :denied
      "navigator.geolocation.getCurrentPosition = (_ok, fail) => setTimeout(() => fail({ code: 1 }), 50)"
    end
    page.execute_script(script)
  end

  it "registers with GPS, is handled by coordination and followed by the author" do
    sign_in_via_ui author
    click_link "Registrar ocorrência", match: :first

    fill_in "Título", with: "Poste apagado na entrada"
    fill_in "Descrição", with: "O poste ao lado da guarita está apagado há duas noites."
    select "Iluminação", from: "Categoria"
    expect(page).to have_no_field("Detalhamento da categoria")

    choose "GPS do aparelho"
    mock_geolocation(:success)
    click_button "Usar minha localização"
    expect(page).to have_content("Localização capturada (precisão aproximada de 18 m)")

    choose "Restrita"
    click_button "Registrar ocorrência"

    expect(page).to have_content("Ocorrência registrada. Protocolo SGU-")
    alert = Alert.last
    expect(alert).to have_attributes(author: author, location_source: "gps", location_accuracy_meters: BigDecimal("18"))
    expect(alert.latitude).to be_within(0.000001).of(-8.0171234)

    Capybara.reset_sessions!
    sign_in_via_ui coordinator
    click_link "Atendimento", match: :first
    click_link "Poste apagado na entrada"
    select "Alta", from: "Prioridade do atendimento"
    fill_in "handling_assessment_reason", with: "Nota interna: avisar manutenção elétrica"
    click_button "Salvar classificação"
    expect(page).to have_content("Classificação do atendimento salva.")

    choose "Em triagem"
    click_button "Atualizar situação"
    choose "Em atendimento"
    click_button "Atualizar situação"
    choose "Resolvida"
    click_button "Atualizar situação"
    expect(page).to have_content("Situação do atendimento atualizada.")
    expect(alert.reload.status).to eq("resolved")

    Capybara.reset_sessions!
    sign_in_via_ui author
    visit alert_path(alert)
    expect(page).to have_content("Resolvida")
    expect(page).to have_content("Em atendimento → Resolvida")
    expect(page).to have_no_content("Nota interna: avisar manutenção elétrica")
    expect(page).to have_no_content("coordenacao@example.com")
  end

  it "explains a denied permission and falls back to a catalog location" do
    create(:location, name: "Prédio de demonstração (fictício)")
    sign_in_via_ui author
    visit new_alert_path

    choose "GPS do aparelho"
    mock_geolocation(:denied)
    click_button "Usar minha localização"
    expect(page).to have_content("Permissão de localização negada. Escolha um local cadastrado")

    choose "Escolha de prédio ou área"
    select "Prédio de demonstração (fictício)", from: "Local do campus"
    fill_in "Título", with: "Bebedouro quebrado"
    fill_in "Descrição", with: "Bebedouro do térreo sem funcionar desde segunda."
    select "Iluminação", from: "Categoria"
    click_button "Registrar ocorrência"

    expect(page).to have_content("Ocorrência registrada")
    expect(Alert.last).to have_attributes(location_source: "manual", latitude: nil)
  end

  it "keeps the typed data and points to the field when validation fails" do
    sign_in_via_ui author
    visit new_alert_path

    fill_in "Título", with: "Abc"
    fill_in "Descrição", with: "Texto curto"
    click_button "Registrar ocorrência"

    expect(page).to have_content("Revise")
    expect(page).to have_field("Título", with: "Abc")
    expect(page).to have_css("#alert_form_new_title[aria-invalid='true']")
    expect(Alert.count).to eq(0)
  end
end
