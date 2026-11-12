require "rails_helper"

RSpec.describe "RF014 — Notificações de postagens", type: :model do
  let(:author) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:alert) { create(:alert, author: author) }

  def configure_external_channels
    allow(Notifications::ChannelConfig).to receive(:email_available?).and_return(true)
    allow(Notifications::ChannelConfig).to receive(:push_available?).and_return(true)
    NotificationPreference.create!(user: author, email_enabled: true)
    PushSubscription.register!(
      session: author.sessions.create!,
      endpoint: "https://fcm.googleapis.com/fcm/send/alisson-test",
      p256dh: WebPush.generate_key.public_key,
      auth: Base64.urlsafe_encode64("a" * 16, padding: false)
    )
  end

  it "RF014-01 encaminha uma mudança de situação para e-mail e push habilitados" do
    subscription = configure_external_channels
    message = instance_double(ActionMailer::MessageDelivery, deliver_now!: true)
    allow(NotificationMailer).to receive(:notice).and_return(message)
    allow(WebPush).to receive(:payload_send)

    Alerts::Transition.call(actor: admin, alert: alert, to: "triaging")

    notice = Notification.where(user: author, alert: alert, kind: "alert_status").sole
    deliveries = NotificationDelivery.where(notification: notice)
    email = deliveries.find_by!(channel: "email")
    push = deliveries.find_by!(channel: "push")
    expect(push.push_subscription).to eq(subscription)

    DeliverNotificationsJob.perform_now

    expect(NotificationMailer).to have_received(:notice).with(email).once
    expect(message).to have_received(:deliver_now!).once
    expect(WebPush).to have_received(:payload_send).with(
      hash_including(endpoint: subscription.endpoint, message: { tag: "sgu-#{notice.id}" }.to_json)
    ).once
    expect(deliveries.pluck(:result)).to contain_exactly("sent", "sent")
  end

  it "RF014-02 mantém um único aviso ao editar o texto e reprocessar a mesma situação" do
    Alerts::Transition.call(actor: admin, alert: alert, to: "triaging")
    notices = Notification.where(user: author, alert: alert, kind: "alert_status")
    original = notices.sole

    Notifications::Events.alert_updated(alert)
    alert.update!(description: "Descrição fictícia revisada sem mudança de situação.")
    Notifications::Events.alert_updated(alert)

    expect(notices.sole.id).to eq(original.id)
  end

  it "RF014-03 não notifica o autor de uma ocorrência anônima" do
    configure_external_channels
    alert.update!(anonymous_public: true)

    expect do
      Alerts::Transition.call(actor: admin, alert: alert, to: "triaging")
    end.not_to change(NotificationDelivery, :count)

    expect(Notification.where(user: author, alert: alert)).to be_empty
  end

  it "RF014-04 notifica a pessoa com local de referência próximo e exclui a distante" do
    origin = create(:location, reference_latitude: -8.01, reference_longitude: -34.95)
    distant = create(:location, reference_latitude: -8.03, reference_longitude: -34.95)
    close = create(:user)
    far = create(:user)
    NotificationPreference.create!(user: close, location: origin)
    NotificationPreference.create!(user: far, location: distant)

    result = Alerts::CreateOccurrence.call(
      actor: author,
      attributes: occurrence_attributes(location_source: "manual", location_id: origin.id, latitude: nil, longitude: nil)
    )

    notices = Notification.where(kind: "nearby_alert", publication: result.alert.publication)
    expect(notices.pluck(:user_id)).to contain_exactly(close.id)
    expect(Notification.visible_to(close)).to exist(notices.sole.id)
  end
end
