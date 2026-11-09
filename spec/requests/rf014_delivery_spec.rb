require "rails_helper"

RSpec.describe "RF014 delivery", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:alert) { create(:alert, author: user) }
  let(:vapid) do
    key = WebPush.generate_key
    { public_key: key.public_key, private_key: key.private_key, subject: "mailto:test@example.test" }
  end
  let(:browser_key) { WebPush.generate_key.public_key }

  def push_attributes
    {
      endpoint: "https://fcm.googleapis.com/fcm/send/test-subscription",
      keys: {
        p256dh: browser_key,
        auth: Base64.urlsafe_encode64("a" * 16, padding: false)
      }
    }
  end

  def opt_in_email(person = user)
    NotificationPreference.create!(user: person, email_enabled: true)
  end

  def transition
    Alerts::Transition.call(actor: admin, alert: alert, to: "triaging")
  end

  it "saves only the signed-in person's choices and sends a generic email once" do
    sign_in(user)
    patch preferences_notifications_path, params: { notification_preference: { email_enabled: "1", user_id: admin.id } }
    expect(response).to have_http_status(:see_other)
    expect(NotificationPreference.find_by!(user: user)).to be_email_enabled
    expect(NotificationPreference.where(user: admin)).to be_empty

    transition
    expect do
      2.times { DeliverNotificationsJob.perform_now }
    end.to change { ActionMailer::Base.deliveries.size }.by(1)
    email = ActionMailer::Base.deliveries.last
    expect(email.to).to eq([ user.email_address ])
    expect(email.body.decoded).to include("/notificacoes")
    expect(email.body.decoded).not_to include(alert.title, alert.protocol)
    expect(NotificationDelivery.last.result).to eq("sent")
  end

  it "retries a transient mail failure and stops delivery if consent is revoked" do
    preference = opt_in_email
    transition
    message = instance_double(ActionMailer::MessageDelivery)
    allow(NotificationMailer).to receive(:notice).and_return(message)
    allow(message).to receive(:deliver_now!).and_raise(Net::ReadTimeout)
    DeliverNotificationsJob.perform_now
    delivery = NotificationDelivery.last
    expect(delivery.attempts).to eq(1)
    expect(delivery.available_at).to be > Time.current
    expect(delivery.finished_at).to be_nil

    preference.update!(email_enabled: false)
    travel 31.seconds do
      DeliverNotificationsJob.perform_now
    end
    expect(message).to have_received(:deliver_now!).once
    expect(delivery.reload.result).to eq("skipped")
  end

  it "does not notify the author of an anonymous post" do
    opt_in_email
    alert.update!(anonymous_public: true)
    expect { transition }.not_to change(NotificationDelivery, :count)
    expect(Notification.where(user: user, alert: alert)).to be_empty
  end

  it "notifies only opted-in people within 500 meters of a visible occurrence" do
    origin = create(:location, reference_latitude: -8.01, reference_longitude: -34.95)
    distant = create(:location, reference_latitude: -8.03, reference_longitude: -34.95)
    close = create(:user)
    far = create(:user)
    NotificationPreference.create!(user: close, location: origin, email_enabled: true)
    NotificationPreference.create!(user: far, location: distant, email_enabled: true)
    NotificationPreference.create!(user: user, location: origin, email_enabled: true)

    result = Alerts::CreateOccurrence.call(actor: user, attributes: occurrence_attributes(
      location_source: "manual", location_id: origin.id, latitude: nil, longitude: nil
    ))
    publication = result.alert.publication
    expect(Notification.where(kind: "nearby_alert", publication: publication).pluck(:user_id)).to eq([ close.id ])
    expect(Notification.visible_to(close).find_by!(publication: publication).kind).to eq("nearby_alert")

    publication.update!(state: "withdrawn", withdrawn_at: Time.current)
    expect(Notification.visible_to(close).where(publication: publication)).to be_empty
    DeliverNotificationsJob.perform_now
    expect(NotificationDelivery.joins(:notification).find_by!(notifications: { user_id: close.id }).result).to eq("skipped")
  end

  it "rejects restricted alert sources for proximity" do
    origin = create(:location, reference_latitude: -8.01, reference_longitude: -34.95)
    NotificationPreference.create!(user: create(:user), location: origin, email_enabled: true)
    Alerts::CreateOccurrence.call(actor: user, attributes: occurrence_attributes(
      requested_visibility: "restricted", location_source: "manual", location_id: origin.id, latitude: nil, longitude: nil
    ))
    expect(Notification.where(kind: "nearby_alert")).to be_empty
  end

  it "registers push for the current session, sends through Web Push and revokes it on logout" do
    allow(Notifications::ChannelConfig).to receive(:vapid).and_return(vapid)
    http = Net::HTTP.new("fcm.googleapis.com", 443)
    allow(Net::HTTP).to receive(:new).with("fcm.googleapis.com", 443).and_return(http)
    allow(http).to receive(:request).and_return(Net::HTTPCreated.new("1.1", "201", "Created"))
    sign_in(user)
    2.times do
      post subscribe_push_notifications_path, params: { subscription: push_attributes }, as: :json
      expect(response).to have_http_status(:no_content)
    end
    expect(PushSubscription.count).to eq(1)
    transition
    2.times { DeliverNotificationsJob.perform_now }
    expect(http).to have_received(:request).once do |request|
      expect(request["Authorization"]).to start_with("vapid ")
      expect(request["Content-Encoding"]).to eq("aes128gcm")
      expect(request.body).not_to include(alert.protocol, "sgu-#{Notification.last.id}")
    end
    delete session_path
    expect(PushSubscription.count).to eq(0)
    expect(NotificationDelivery.where(channel: "push")).to be_empty
  end

  it "rejects arbitrary push destinations and refuses to transfer a device without its authentication secret" do
    allow(Notifications::ChannelConfig).to receive(:vapid).and_return(vapid)
    sign_in(user)
    post subscribe_push_notifications_path, params: { subscription: push_attributes.merge(endpoint: "https://fcm.googleapis.com.evil.test/metadata") }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(PushSubscription.count).to eq(0)
    post subscribe_push_notifications_path, params: { subscription: push_attributes }, as: :json
    expect(response).to have_http_status(:no_content)

    sign_in(admin)
    attributes = push_attributes
    attributes[:keys][:auth] = Base64.urlsafe_encode64("b" * 16, padding: false)
    post subscribe_push_notifications_path, params: { subscription: attributes }, as: :json
    expect(response).to have_http_status(:not_found)
    expect(PushSubscription.sole.session.user).to eq(user)
  end

  it "serves the service worker without requiring a session" do
    get pwa_service_worker_path
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to include("javascript")
    expect(response.body).to include('addEventListener("push"', "showNotification", "/notificacoes")
  end

  it "keeps external messages in the originating transaction" do
    opt_in_email
    expect do
      Alert.transaction do
        transition
        raise ActiveRecord::Rollback
      end
    end.not_to change(NotificationDelivery, :count)
    expect(Notification.where(user: user)).to be_empty
  end

  it "releases an expired push subscription after a provider returns 410" do
    allow(Notifications::ChannelConfig).to receive(:vapid).and_return(vapid)
    http = Net::HTTP.new("fcm.googleapis.com", 443)
    allow(Net::HTTP).to receive(:new).with("fcm.googleapis.com", 443).and_return(http)
    response = Net::HTTPGone.new("1.1", "410", "Gone")
    allow(response).to receive(:body).and_return("")
    allow(http).to receive(:request).and_return(response)
    sign_in(user)
    post subscribe_push_notifications_path, params: { subscription: push_attributes }, as: :json
    transition
    DeliverNotificationsJob.perform_now
    expect(PushSubscription.count).to eq(0)
    expect(NotificationDelivery.count).to eq(0)
  end

  it "bounds retries after repeated failure" do
    opt_in_email
    transition
    message = instance_double(ActionMailer::MessageDelivery)
    allow(NotificationMailer).to receive(:notice).and_return(message)
    allow(message).to receive(:deliver_now!).and_raise(Net::ReadTimeout)
    6.times do |index|
      travel((10 * (index + 1)).minutes) { DeliverNotificationsJob.perform_now }
    end
    expect(message).to have_received(:deliver_now!).exactly(5).times
    expect(NotificationDelivery.sole).to have_attributes(attempts: 5, result: "failed")
  end

  it "does not call a provider for an already claimed delivery" do
    opt_in_email
    transition
    NotificationDelivery.sole.update!(available_at: 5.minutes.from_now)
    expect(NotificationMailer).not_to receive(:notice)
    DeliverNotificationsJob.perform_now
    expect(NotificationDelivery.sole.finished_at).to be_nil
  end

  it "requires authentication for opt-in and device registration" do
    patch preferences_notifications_path, params: { notification_preference: { email_enabled: "1" } }
    expect(response).to have_http_status(:redirect)
    post subscribe_push_notifications_path, params: { subscription: push_attributes }, as: :json
    expect(response).to have_http_status(:redirect)
    expect(NotificationPreference.count).to eq(0)
    expect(PushSubscription.count).to eq(0)
  end
end
