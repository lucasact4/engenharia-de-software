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

  it "RNF001 records the push delivery with the time since the panic was created" do
    responder = create(:user).tap { |user| grant_role(user, :security) }
    alert = create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9)
    subscription = responder.security_push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/latency", p256dh: Base64.urlsafe_encode64("\x04" + "\0" * 64, padding: false),
      auth: Base64.urlsafe_encode64("\0" * 16, padding: false)
    )
    allow(Notifications::ChannelConfig).to receive_messages(
      push_available?: true, vapid: { public_key: "public", private_key: "private", subject: "mailto:sgu@example.test" }
    )
    allow(WebPush).to receive(:payload_send)

    travel_to(alert.created_at + 1.4.seconds, with_usec: true) { described_class.perform_now(alert.id, subscription.id) }

    delivery = PanicDelivery.sole
    expect(delivery).to have_attributes(alert: alert, user: responder, channel: "push", status: "sent", latency_ms: 1_400)
    expect(delivery).to be_within_target
  end

  it "RNF001 records a failed push and removes an expired device" do
    responder = create(:user).tap { |user| grant_role(user, :security) }
    alert = create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9)
    subscription = responder.security_push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/expired", p256dh: Base64.urlsafe_encode64("\x04" + "\0" * 64, padding: false),
      auth: Base64.urlsafe_encode64("\0" * 16, padding: false)
    )
    allow(Notifications::ChannelConfig).to receive_messages(
      push_available?: true, vapid: { public_key: "public", private_key: "private", subject: "mailto:sgu@example.test" }
    )
    response = instance_double(Net::HTTPGone, body: "", inspect: "gone")
    allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(response, "fcm.googleapis.com"))

    described_class.perform_now(alert.id, subscription.id)

    expect(PanicDelivery.sole).to have_attributes(channel: "push", status: "failed", error_message: "ExpiredSubscription")
    expect(SecurityPushSubscription.exists?(subscription.id)).to be(false)
  end
end
