require "rails_helper"

RSpec.describe "Pânico público no mural e entrega do alerta (RF011/RNF001)", type: :request do
  let(:author) { create(:user, :public_profile, display_name: "Autora Fictícia") }
  let(:message) { "Alguém está fazendo assaltos no caminho do Transrural, perto do CEAGRI 2." }

  def create_panic(public_warning:, description: message, key: SecureRandom.uuid)
    sign_in(author)
    post panic_path, params: {
      client_request_id: key,
      panic: { latitude: "-8.0171", longitude: "-34.9500", description: description, public_warning: (public_warning ? "1" : nil) }.compact
    }, as: :json
    Alert.panic.find_by(author: author, client_request_id: key)
  end

  it "mostra o pânico público no topo do mural para quem não está logado, sem o autor e sem GPS exato" do
    alert = create_panic(public_warning: true)
    expect(response).to have_http_status(:created)
    expect(alert).to have_attributes(public_warning: true, visibility: "restricted")
    delete session_path

    get publications_path

    warning = Nokogiri::HTML(response.body).at_css(".public-warnings")
    expect(warning.text).to include("Alertas de segurança ativos", message, "Recebida")
    expect(warning.text).not_to include("Autora Fictícia")
    expect(warning.text).not_to include("-8.0171")
  end

  it "também mostra o aviso no mapa do campus" do
    create_panic(public_warning: true)

    get campus_map_path

    expect(Nokogiri::HTML(response.body).at_css(".public-warnings").text).to include(message)
  end

  it "mantém o pânico privado fora do mural" do
    create_panic(public_warning: false, description: "Pedido privado de ajuda na biblioteca.")

    get publications_path

    expect(response.body).not_to include("Pedido privado de ajuda na biblioteca.")
    expect(Nokogiri::HTML(response.body).at_css(".public-warnings")).to be_nil
  end

  it "exige uma descrição para avisar a comunidade" do
    key = SecureRandom.uuid

    expect { create_panic(public_warning: true, description: "", key: key) }.not_to change(Alert.panic, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["message"]).to include("avisar a comunidade")
  end

  it "tira o aviso do mural quando o pedido é encerrado ou passa da janela de 12 horas" do
    resolved = create_panic(public_warning: true)
    resolved.update_columns(status: "resolved", resolved_at: Time.current)
    old = create_panic(public_warning: true, description: "Aviso antigo de risco no estacionamento.")
    old.update_columns(created_at: 13.hours.ago)

    get publications_path

    expect(Nokogiri::HTML(response.body).at_css(".public-warnings")).to be_nil
  end

  it "deixa a segurança retirar o aviso público e registra a auditoria" do
    alert = create_panic(public_warning: true)
    officer = create(:user).tap { |user| grant_role(user, :security) }
    sign_in(officer)

    expect do
      patch public_warning_handling_alert_path(alert)
    end.to change { AuditEvent.where(action: "alert.public_warning_withdrawn").count }.by(1)

    expect(response).to redirect_to(handling_alert_path(alert, locale: I18n.locale))
    expect(alert.reload).to have_attributes(public_warning_withdrawn_by: officer)
    get publications_path
    expect(response.body).not_to include(message)
  end

  it "não deixa quem não é da segurança retirar o aviso" do
    alert = create_panic(public_warning: true)
    coordination = create(:user).tap { |user| grant_role(user, :coordination) }
    sign_in(coordination)

    patch public_warning_handling_alert_path(alert)

    expect(alert.reload.public_warning_withdrawn_at).to be_nil
  end

  it "mostra no atendimento quanto tempo o primeiro aviso levou (RNF001)" do
    alert = create_panic(public_warning: true)
    officer = create(:user, display_name: "Agente Fictício").tap { |user| grant_role(user, :security) }
    PanicDelivery.create!(alert: alert, user: officer, channel: "push", status: "sent", latency_ms: 1_200)
    sign_in(officer)

    get handling_alert_path(alert)

    panel = Nokogiri::HTML(response.body).at_css("[aria-labelledby='panic-dispatch-title']")
    expect(panel.text).to include("Primeiro aviso em 1,2 s", "dentro da meta", "Agente Fictício", "Aviso público ativo")
    expect(panel.at_css("form[action='#{public_warning_handling_alert_path(alert, locale: I18n.locale)}']")).to be_present
  end
end
