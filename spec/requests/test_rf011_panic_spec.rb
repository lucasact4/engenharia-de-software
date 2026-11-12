require "rails_helper"

RSpec.describe "RF011 — Botão do pânico", type: :request do
  let(:author) { create(:user) }
  let(:key) { SecureRandom.uuid }

  it "RF011-01 exige uma conta autenticada para receber um pedido de pânico" do
    expect do
      post panic_path, params: { client_request_id: key }, as: :json
    end.not_to change(Alert.panic, :count)

    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
  end

  it "RF011-02 apresenta uma confirmação separada antes de enviar o formulário" do
    sign_in(author)

    expect { get new_panic_path }.not_to change(Alert.panic, :count)
    expect(response).to have_http_status(:ok)

    page = Nokogiri::HTML(response.body)
    form = page.at_css("form#panic_form")
    expect(form["action"]).to eq(panic_path(locale: I18n.locale))
    expect(form.at_css('button[type="button"][data-action="panic#arm"]').text).to include("Pedir ajuda")
    expect(form.at_css('[data-panic-target="confirm"] button[type="submit"]').text).to include("Confirmar pedido de ajuda")
    expect(form.at_css('[data-panic-target="confirm"] button[data-action="panic#disarm"]').text).to include("Cancelar")
  end

  it "RF011-03 registra GPS e motivo no pedido restrito recebido pela segurança" do
    officer = create(:user)
    grant_role(officer, :security)
    sign_in(author)

    expect do
      post panic_path, params: {
        client_request_id: key,
        panic: { latitude: "-8.01", longitude: "-34.95", description: "Pedido fictício de ajuda" }
      }, as: :json
    end.to change(Alert.panic, :count).by(1)

    expect(response).to have_http_status(:created)
    alert = Alert.panic.find_by!(author: author, client_request_id: key)
    expect(alert).to have_attributes(
      location_source: "gps", latitude: BigDecimal("-8.01"), longitude: BigDecimal("-34.95"),
      description: "Pedido fictício de ajuda", visibility: "restricted"
    )
    expect(JSON.parse(response.body)).to include("protocol" => alert.protocol)
    expect(Notification.visible_to(officer).where(alert: alert, kind: "panic")).to exist
  end

  it "RF011-04 prioriza a proximidade na seleção de destinatários da segurança" do
    close = create(:user)
    far = create(:user)
    grant_role(close, :security)
    grant_role(far, :security)

    origin = create(:location, reference_latitude: -8.01, reference_longitude: -34.95)
    distant = create(:location, reference_latitude: -8.21, reference_longitude: -34.95)
    NotificationPreference.create!(user: close, location: origin)
    NotificationPreference.create!(user: far, location: distant)

    alert = Alerts::CreatePanic.call(
      actor: author, client_request_id: key, attributes: { latitude: "-8.01", longitude: "-34.95" }
    ).alert

    security_recipients = Notification.where(alert: alert, kind: "panic", user: [ close, far ]).pluck(:user_id)
    expect(security_recipients).to contain_exactly(close.id),
      "O destinatário próximo deveria ser selecionado sem notificar o distante. Próximo notificado: #{security_recipients.include?(close.id)}. Distante notificado: #{security_recipients.include?(far.id)}."
  end
end
