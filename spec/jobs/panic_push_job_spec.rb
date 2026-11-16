require "rails_helper"

RSpec.describe PanicPushJob, type: :job do
  it "sends a high urgency web push that opens the panic handling queue" do
    responder = create(:user).tap { |user| grant_role(user, :security) }
    alert = create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9)
    SecurityPresence.create!(user: responder, latitude: -8.0, longitude: -34.9, reported_at: Time.current)
    subscription = responder.security_push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/device", p256dh: Base64.urlsafe_encode64("\x04" + "\0" * 64, padding: false),
      auth: Base64.urlsafe_encode64("\0" * 16, padding: false)
    )
    allow(Notifications::ChannelConfig).to receive_messages(
      push_available?: true,
      vapid: { public_key: "public", private_key: "private", subject: "mailto:sgu@example.test" }
    )

    expect(WebPush).to receive(:payload_send).with(hash_including(
      endpoint: subscription.endpoint, urgency: "high", ttl: 60,
      open_timeout: 5, read_timeout: 5, ssl_timeout: 5,
      vapid: hash_including(public_key: "public", private_key: "private")
    ))

    described_class.perform_now(alert.id, subscription.id)
  end
end
