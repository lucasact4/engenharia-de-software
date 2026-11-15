require "rails_helper"

RSpec.describe PanicPushJob, type: :job do
  it "sends a high urgency web push that opens the panic handling queue" do
    responder = create(:user).tap { |user| grant_role(user, :security) }
    alert = create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9)
    SecurityPresence.create!(user: responder, latitude: -8.0, longitude: -34.9, reported_at: Time.current)
    subscription = responder.security_push_subscriptions.create!(
      endpoint: "https://push.example.test/device", p256dh: "p256dh", auth: "auth"
    )
    allow(ENV).to receive(:values_at).with("VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY", "VAPID_SUBJECT").and_return(%w[public private mailto:sgu@example.test])
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("VAPID_PUBLIC_KEY").and_return("public")
    allow(ENV).to receive(:fetch).with("VAPID_PRIVATE_KEY").and_return("private")
    allow(ENV).to receive(:fetch).with("VAPID_SUBJECT").and_return("mailto:sgu@example.test")

    expect(WebPush).to receive(:payload_send).with(hash_including(
      endpoint: subscription.endpoint, urgency: "high", ttl: 60,
      open_timeout: 5, read_timeout: 5, ssl_timeout: 5,
      vapid: hash_including(public_key: "public", private_key: "private")
    ))

    described_class.perform_now(alert.id, subscription.id)
  end
end
