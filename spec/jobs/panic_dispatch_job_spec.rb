require "rails_helper"

RSpec.describe PanicDispatchJob, type: :job do
  it "queues an emergency email and push for the selected nearby security responder" do
    responder = create(:user).tap { |user| grant_role(user, :security) }
    alert = create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9)
    SecurityPresence.create!(user: responder, latitude: -8.0001, longitude: -34.9, reported_at: Time.current)
    subscription = responder.security_push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/device", p256dh: Base64.urlsafe_encode64("\x04" + "\0" * 64, padding: false),
      auth: Base64.urlsafe_encode64("\0" * 16, padding: false)
    )

    expect {
      described_class.perform_now(alert.id)
    }.to have_enqueued_mail(PanicAlertMailer, :emergency).with(alert, responder)
      .and have_enqueued_job(PanicPushJob).with(alert.id, subscription.id)
  end

  it "queues emergency push for administrators who enabled it on their device" do
    responder = create(:user).tap { |user| grant_role(user, :security) }
    admin = create(:user, :admin)
    alert = create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9)
    SecurityPresence.create!(user: responder, latitude: -8.0001, longitude: -34.9, reported_at: Time.current)
    subscription = admin.security_push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/admin", p256dh: Base64.urlsafe_encode64("\x04" + "\0" * 64, padding: false),
      auth: Base64.urlsafe_encode64("\0" * 16, padding: false)
    )

    expect {
      described_class.perform_now(alert.id)
    }.to have_enqueued_mail(PanicAlertMailer, :emergency).with(alert, admin)
      .and have_enqueued_job(PanicPushJob).with(alert.id, subscription.id)
  end
end
