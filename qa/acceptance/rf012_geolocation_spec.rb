require "rails_helper"

RSpec.describe "RF012 - Geolocalização em tempo real", type: :feature, js: true do
  let(:author) { create(:user) }
  let(:stop_label) { /(?:parar|interromper|encerrar).*(?:rastreamento|acompanhamento|localização)/i }
  let(:stopped_message) { /(?:rastreamento|acompanhamento|localização).*(?:encerrad[oa]|interrompid[oa]|desativad[oa])/i }

  def mock_gps
    page.execute_script(<<~JS)
      const position = {
        coords: { latitude: -8.0171234, longitude: -34.9501234, accuracy: 18 },
        timestamp: Date.now()
      };
      sessionStorage.setItem("rf012-gps-watch-count", "0");
      navigator.geolocation.getCurrentPosition = (success) => success(position);
      navigator.geolocation.watchPosition = (success) => {
        const count = Number(sessionStorage.getItem("rf012-gps-watch-count")) + 1;
        sessionStorage.setItem("rf012-gps-watch-count", String(count));
        success(position);
        return count;
      };
    JS
  end

  def gps_watch_count
    page.evaluate_script('Number(sessionStorage.getItem("rf012-gps-watch-count"))')
  end

  it "RF012-01 inicia monitoramento contínuo ao confirmar um pânico com GPS" do
    sign_in_via_ui author
    visit new_panic_path
    mock_gps

    click_button "Pedir ajuda"
    click_button "Confirmar pedido de ajuda"

    expect(page).to have_content("O sistema recebeu este pedido de ajuda")
    expect(Alert.panic.find_by!(author: author)).to have_attributes(location_source: "gps")
    expect(gps_watch_count).to be_positive,
      "O GPS inicial foi registrado, mas o navegador não iniciou o monitoramento contínuo (watchPosition)."
  end

  it "RF012-02 permite ao autor interromper o acompanhamento no detalhe do pânico" do
    alert = create(:alert, :panic, author: author, location_source: "gps", latitude: -8.0171234, longitude: -34.9501234)
    sign_in_via_ui author
    visit alert_path(alert)

    expect(page).to have_content(alert.protocol)
    expect(page).to have_button(text: stop_label),
      "O detalhe do pânico do autor não oferece um botão para interromper o acompanhamento."
    find(:button, text: stop_label).click
    expect(page).to have_content(stopped_message)
  end

  it "RF012-03 permite ao administrador interromper o acompanhamento pelo painel" do
    alert = create(:alert, :panic, author: author, location_source: "gps", latitude: -8.0171234, longitude: -34.9501234)
    sign_in_via_ui create(:user, :admin)
    visit admin_alert_path(alert)

    expect(page).to have_content(alert.protocol)
    expect(page).to have_button(text: stop_label),
      "O detalhe administrativo do pânico não oferece um botão para interromper o acompanhamento."
    find(:button, text: stop_label).click
    expect(page).to have_content(stopped_message)
  end

  it "RF012-04 registra o GPS da ocorrência comum sem iniciar monitoramento contínuo" do
    category = create(:category, name: "Iluminação")
    sign_in_via_ui author
    visit new_alert_path
    mock_gps

    fill_in "Título", with: "Poste apagado perto da guarita"
    fill_in "Descrição", with: "O poste ao lado da guarita está apagado há duas noites."
    select category.name, from: "Categoria"
    choose "Usar GPS", allow_label_click: true
    click_button "Usar minha localização"
    expect(page).to have_content("Localização capturada")
    select "Somente eu e o atendimento", from: "Quem pode ver"
    click_button "Publicar ocorrência"

    expect(page).to have_content("Ocorrência registrada")
    alert = Alert.find_by!(author: author, title: "Poste apagado perto da guarita")
    expect(alert.latitude).to be_within(0.000001).of(-8.0171234)
    expect(alert.longitude).to be_within(0.000001).of(-34.9501234)
    expect(gps_watch_count).to eq(0)
  end
end
