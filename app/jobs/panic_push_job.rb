class PanicPushJob < ApplicationJob
  queue_as :critical

  def perform(alert_id, subscription_id)
    return unless Notifications::ChannelConfig.push_available?

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
      vapid: Notifications::ChannelConfig.vapid,
      ttl: 60,
      urgency: "high",
      ssl_timeout: 5,
      open_timeout: 5,
      read_timeout: 5
    )
    PanicDelivery.record!(alert: alert, user: subscription.user, channel: "push")
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription => error
    PanicDelivery.record!(alert: alert, user: subscription.user, channel: "push", status: "failed", error: error.class.name.demodulize) if alert && subscription
    subscription&.destroy
  rescue WebPush::ResponseError => error
    PanicDelivery.record!(alert: alert, user: subscription.user, channel: "push", status: "failed", error: error.class.name.demodulize)
    raise
  end
end
