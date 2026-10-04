require "rails_helper"

RSpec.describe "Panic alerts", type: :request do
  let(:user) { create(:user) }
  let(:key) { SecureRandom.uuid }

  before { sign_in(user) }

  it "shows an intentional confirmation with a server-generated key and an honest message" do
    get new_panic_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="client_request_id"')
    expect(response.body).to include("Confirmar pedido de ajuda")
    expect(response.body).to include("não aciona viaturas")
  end

  it "creates a restricted panic without location, title, category or photo" do
    expect do
      post panic_path, params: { client_request_id: key, panic: { location_unavailable_reason: "permission_denied" } }
    end.to change(Alert.panic, :count).by(1)

    alert = Alert.panic.last
    expect(alert).to have_attributes(author: user, visibility: "restricted", requested_visibility: "restricted",
                                     location_source: "unavailable", location_unavailable_reason: "permission_denied",
                                     title: nil, category: nil)
    expect(response).to redirect_to(alert_path(alert, locale: I18n.locale))
    follow_redirect!
    expect(response.body).to include("O sistema recebeu este pedido de ajuda")
    expect(response.body).to include("não significa que uma pessoa já viu")
  end

  it "uses GPS when available and drops conflicting fields" do
    location = create(:location)
    post panic_path, params: { client_request_id: key, panic: { latitude: "-8.01", longitude: "-34.95", location_id: location.id,
                                                                location_unavailable_reason: "timeout" } }

    expect(Alert.panic.last).to have_attributes(location_source: "gps", location_id: nil, location_unavailable_reason: nil)
  end

  it "is idempotent for retries with the same key and payload (JSON and HTML)" do
    params = { client_request_id: key, panic: { location_unavailable_reason: "timeout", description: "Socorro" } }

    post panic_path, params: params, as: :json
    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body).to include("protocol", "url")
    expect(body).not_to include("latitude", "author_id", "email_address")

    expect { post panic_path, params: params, as: :json }.not_to change(Alert, :count)
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["created"]).to be(false)

    expect { post panic_path, params: params }.not_to change(Alert, :count)
  end

  it "returns 409 when the same key arrives with a different payload (late GPS)" do
    post panic_path, params: { client_request_id: key, panic: { location_unavailable_reason: "timeout" } }, as: :json

    expect do
      post panic_path, params: { client_request_id: key, panic: { latitude: "-8.01", longitude: "-34.95" } }, as: :json
    end.not_to change(Alert, :count)
    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body)["message"]).to include("Meus alertas")

    post panic_path, params: { client_request_id: key, panic: { latitude: "-8.01", longitude: "-34.95" } }
    expect(response).to have_http_status(:conflict)
  end

  it "requires a valid key" do
    expect { post panic_path, params: { panic: {} }, as: :json }.not_to change(Alert, :count)
    expect(response).to have_http_status(:unprocessable_entity)

    expect { post panic_path, params: { client_request_id: "123", panic: {} } }.not_to change(Alert, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "never reaches the social or editorial features" do
    post panic_path, params: { client_request_id: key, panic: {} }
    panic = Alert.panic.last

    post alert_subscription_path(panic)
    expect(AlertSubscription.count).to eq(0)

    expect(PublicationSourcesQuery.new(create(:user, :admin)).call).not_to include(panic)
  end

  it "is visible to security in the queue but not to coordination or other users" do
    post panic_path, params: { client_request_id: key, panic: {} }
    panic = Alert.panic.last

    security = create(:user).tap { |u| grant_role(u, :security) }
    coordination = create(:user).tap { |u| grant_role(u, :coordination) }

    sign_in(security)
    get handling_alerts_path(kind: "panic")
    expect(response.body).to include(panic.protocol)

    sign_in(coordination)
    get handling_alert_path(panic)
    expect(response).to have_http_status(:not_found)

    sign_in(create(:user))
    get alert_path(panic)
    expect(response).to have_http_status(:not_found)
  end
end
