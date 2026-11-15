require "rails_helper"

RSpec.describe "Security emergency setup", type: :request do
  let(:security) { create(:user).tap { |user| grant_role(user, :security) } }

  it "lets an active security user share and stop live on-duty presence" do
    sign_in(security)

    post security_presence_path, params: { latitude: -8.0, longitude: -34.9 }, as: :json
    expect(response).to have_http_status(:no_content)
    expect(security.reload.security_presence).to have_attributes(latitude: -8.0, longitude: -34.9)

    delete security_presence_path, as: :json
    expect(response).to have_http_status(:no_content)
    expect(security.reload.security_presence).to be_nil
  end

  it "rejects invalid coordinates and users without the security role" do
    sign_in(security)
    post security_presence_path, params: { latitude: 91, longitude: -34.9 }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    sign_in(create(:user))
    post security_presence_path, params: { latitude: -8.0, longitude: -34.9 }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "stores a valid push subscription only for an active security account" do
    sign_in(security)
    post security_push_subscription_path, params: {
      subscription: { endpoint: "https://push.example.test/token", keys: { p256dh: "public", auth: "secret" } }
    }, as: :json

    expect(response).to have_http_status(:created)
    expect(security.security_push_subscriptions.count).to eq(1)
  end

  it "allows administrators to register a push subscription without granting them a security presence" do
    admin = create(:user, :admin)
    sign_in(admin)

    post security_push_subscription_path, params: {
      subscription: { endpoint: "https://push.example.test/admin-token", keys: { p256dh: "public", auth: "secret" } }
    }, as: :json

    expect(response).to have_http_status(:created)
    expect(admin.security_push_subscriptions.count).to eq(1)

    post security_presence_path, params: { latitude: -8.0, longitude: -34.9 }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "shows emergency push setup to security and administrators, and presence setup only to security" do
    sign_in(security)
    get panel_path
    expect(response.body).to include("Ativar push de emergência", "Compartilhar localização durante o plantão")

    get service_worker_path
    expect(response).to have_http_status(:ok), response.body[/<h1.*?<\/h1>/m]
    expect(response.headers["Service-Worker-Allowed"]).to eq("/")
    expect(response.body).to include('addEventListener("push"')

    sign_in(create(:user))
    get panel_path
    expect(response.body).not_to include("Compartilhar localização durante o plantão")

    sign_in(create(:user, :admin))
    get panel_path
    expect(response.body).to include("Ativar push de emergência")
    expect(response.body).not_to include("Compartilhar localização durante o plantão")

    get service_worker_path
    expect(response).to have_http_status(:ok), response.body[/<h1.*?<\/h1>/m]
    expect(response.headers["Service-Worker-Allowed"]).to eq("/")
    expect(response.body).to include('addEventListener("push"')
  end

  it "clears expired on-duty coordinates" do
    presence = SecurityPresence.create!(user: security, latitude: -8.0, longitude: -34.9,
                                        reported_at: SecurityPresence::FRESH_FOR.ago - 1.second)

    SecurityPresenceCleanupJob.perform_now

    expect(SecurityPresence.exists?(presence.id)).to be(false)
  end
end
