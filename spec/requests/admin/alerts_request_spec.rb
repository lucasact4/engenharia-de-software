require "rails_helper"

RSpec.describe "Admin alerts", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:author) { create(:user) }
  let!(:alert) { create(:alert, :public_request, author: author, title: "Árvore caída no estacionamento") }

  before { sign_in(admin) }

  it "lists with filters, sorting and pagination inside the scope" do
    panic = create(:alert, :panic)
    create_list(:alert, 21, title: "Registro em massa")

    get admin_alerts_path(q: "árvore")
    expect(response.body).to include("Árvore caída no estacionamento")
    expect(response.body).not_to include("Registro em massa")

    get admin_alerts_path(kind: "panic", sort: "prioridade")
    expect(response.body).to include(panic.protocol)
    expect(response.body).not_to include(alert.protocol)

    get admin_alerts_path(status: "closed")
    expect(response.body).to include("Nenhum alerta encontrado")

    get admin_alerts_path(from: Date.tomorrow.iso8601)
    expect(response.body).to include("Nenhum alerta encontrado")

    get admin_alerts_path(sort: "'; DROP TABLE alerts; --", page: 2)
    expect(response).to have_http_status(:ok)
    expect(Alert.count).to eq(23)
  end

  it "shows operational details, photos and the editorial shortcut" do
    get admin_alert_path(alert)

    expect(response.body).to include(author.email_address)
    expect(response.body).not_to include("Preparar publicação")
    expect(response.body).to include("Audiência e divulgação")
  end

  it "creates an occurrence authored by the admin, never on behalf of someone else" do
    post admin_alerts_path, params: {
      client_request_id: SecureRandom.uuid,
      alert: occurrence_attributes(author_id: author.id, requested_visibility: "restricted")
    }

    created = Alert.order(:id).last
    expect(created.author).to eq(admin)
    expect(response).to redirect_to(admin_alert_path(created, locale: I18n.locale))
  end

  it "corrects text with a reason and audit, without touching location or reported severity" do
    patch admin_alert_path(alert), params: {
      lock_version: alert.lock_version, reason: "Remoção de dado pessoal exposto",
      alert: { title: "Árvore caída (corrigido)", description: alert.description, category_id: alert.category_id,
               latitude: "1", longitude: "1", reported_severity: "critical" }
    }

    expect(alert.reload).to have_attributes(title: "Árvore caída (corrigido)", latitude: BigDecimal("-8.0"), reported_severity: nil)
    event = AuditEvent.find_by(subject: alert, action: "alert.content_corrected")
    expect(event.reason).to eq("Remoção de dado pessoal exposto")
  end

  it "requires a reason for corrections and rejects stale versions with 409" do
    patch admin_alert_path(alert), params: { lock_version: alert.lock_version, alert: { title: "Sem motivo nenhum" } }
    expect(response).to have_http_status(:unprocessable_entity)

    stale = alert.lock_version
    alert.update!(priority: "high")
    patch admin_alert_path(alert), params: { lock_version: stale, reason: "x", alert: { title: "Versão antiga" } }
    expect(response).to have_http_status(:conflict)
    expect(response.body).to include("Versão antiga")
    expect(alert.reload.title).not_to eq("Versão antiga")
  end

  it "restricts with a reason and withdraws a published projection" do
    publication = create(:publication, :published, kind: "occurrence", alert: alert, visibility: "public_external")

    patch restriction_admin_alert_path(alert), params: { lock_version: alert.lock_version, reason: "Exposição indevida" }

    expect(alert.reload).to have_attributes(publication_blocked: true, visibility: "restricted", requested_visibility: "public_external")
    expect(publication.reload).to be_withdrawn

    get publication_path(publication)
    expect(response).to have_http_status(:not_found)
  end

  it "requires a reason to expand the audience" do
    alert.update!(requested_visibility: "restricted")

    patch audience_admin_alert_path(alert), params: { lock_version: alert.lock_version, requested_visibility: "internal" }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(alert.reload.requested_visibility).to eq("restricted")

    patch audience_admin_alert_path(alert), params: { lock_version: alert.lock_version, requested_visibility: "internal", reason: "Autor pediu" }
    expect(alert.reload).to have_attributes(requested_visibility: "internal", visibility: "internal")
  end

  it "has no destroy route" do
    expect { delete "/admin/ocorrencias/#{alert.id}" }.not_to change(Alert, :count)
    expect(response).to have_http_status(:not_found)
  end
end
