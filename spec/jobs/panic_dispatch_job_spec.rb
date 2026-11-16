require "rails_helper"

RSpec.describe PanicDispatchJob, type: :job do
  it "queues an emergency email and push for a security responder" do
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

  it "RF011 queues email and push for every security responder, near or far, and every administrator" do
    alert = create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9)
    responders = [ -8.0001, -8.0002, -8.0003, -8.2 ].map do |latitude|
      create(:user).tap do |user|
        grant_role(user, :security)
        SecurityPresence.create!(user: user, latitude: latitude, longitude: -34.9, reported_at: Time.current)
      end
    end
    off_duty = create(:user).tap { |user| grant_role(user, :security) }
    admin = create(:user, :admin)
    far_device = responders.last.security_push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/far", p256dh: Base64.urlsafe_encode64("\x04" + "\0" * 64, padding: false),
      auth: Base64.urlsafe_encode64("\0" * 16, padding: false)
    )

    expect {
      described_class.perform_now(alert.id)
    }.to have_enqueued_mail(PanicAlertMailer, :emergency).exactly(6).times
      .and have_enqueued_mail(PanicAlertMailer, :emergency).with(alert, responders.last)
      .and have_enqueued_mail(PanicAlertMailer, :emergency).with(alert, off_duty)
      .and have_enqueued_mail(PanicAlertMailer, :emergency).with(alert, admin)
      .and have_enqueued_job(PanicPushJob).with(alert.id, far_device.id)
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
