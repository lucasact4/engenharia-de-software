class PanicPushJob < ApplicationJob
  queue_as :critical

  def perform(alert_id, subscription_id)
    return unless ENV.values_at("VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY", "VAPID_SUBJECT").all?(&:present?)

    alert = Alert.panic.find_by(id: alert_id)
    subscription = SecurityPushSubscription.find_by(id: subscription_id)
    return unless alert && subscription && PanicRecipientsQuery.new(alert).call.include?(subscription.user)

    WebPush.payload_send(
      message: {
        title: "🚨 EMERGÊNCIA · Botão do pânico",
        body: "Pedido #{alert.protocol} recebido. Toque para abrir o atendimento.",
        icon: "/icon.png",
        tag: "panic-#{alert.id}",
        requireInteraction: true,
        data: { path: Rails.application.routes.url_helpers.handling_alert_path(alert) }
      }.to_json,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: {
        subject: ENV.fetch("VAPID_SUBJECT"),
        public_key: ENV.fetch("VAPID_PUBLIC_KEY"),
        private_key: ENV.fetch("VAPID_PRIVATE_KEY")
      },
      ttl: 60,
      urgency: "high",
      ssl_timeout: 5,
      open_timeout: 5,
      read_timeout: 5
    )
  rescue WebPush::ExpiredSubscription
    subscription&.destroy
  end
end
