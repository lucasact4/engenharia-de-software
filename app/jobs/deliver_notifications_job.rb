class DeliverNotificationsJob < ApplicationJob
  self.queue_adapter = :solid_queue unless Rails.env.test?
  queue_as :default

  MAX_ATTEMPTS = 5

  def perform
    NotificationDelivery.due.order(:available_at, :id).limit(30).each do |delivery|
      # Reserva atômica antes da rede. Se o processo cair, a reserva expira e o envio pode ser retomado.
      claimed = NotificationDelivery.due.where(id: delivery.id).update_all(available_at: 5.minutes.from_now)
      deliver(delivery) if claimed == 1
    end
  end

  private

    def deliver(delivery)
      notification = delivery.notification
      user = notification.user
      unless Notification.visible_to(user).exists?(notification.id) &&
          (notification.kind != "nearby_alert" || Notifications::Nearby.current_match?(notification)) &&
          !notification.anonymous_author_notice?
        return finish(delivery, "skipped")
      end

      if delivery.channel == "email"
        return finish(delivery, "skipped") unless Notifications::ChannelConfig.email_available? &&
          NotificationPreference.exists?(user_id: user.id, email_enabled: true)

        NotificationMailer.notice(delivery).deliver_now!
      else
        subscription = delivery.push_subscription
        return finish(delivery, "skipped") unless subscription && subscription.session.user_id == user.id &&
          subscription.session.created_at >= Authentication::SESSION_DURATION.ago &&
          Notifications::ChannelConfig.push_available? && PushSubscription.allowed_endpoint?(subscription.endpoint)

        WebPush.payload_send(
          endpoint: subscription.endpoint, p256dh: subscription.p256dh, auth: subscription.auth,
          vapid: Notifications::ChannelConfig.vapid, ttl: 900, open_timeout: 5, read_timeout: 5, ssl_timeout: 5,
          message: { tag: "sgu-#{notification.id}" }.to_json
        )
      end

      finish(delivery, "sent")
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      delivery.push_subscription&.destroy!
    rescue StandardError => error
      # Evita incluir endpoint, e-mail, coordenadas ou resposta do provedor no log.
      Rails.logger.warn("Notification delivery #{delivery.id}: #{error.class}")
      attempts = delivery.attempts + 1
      if attempts >= MAX_ATTEMPTS
        delivery.update_columns(attempts: attempts, finished_at: Time.current, result: "failed")
      else
        delivery.update_columns(attempts: attempts, available_at: (30 * 2**(attempts - 1)).seconds.from_now)
      end
    end

    def finish(delivery, result)
      delivery.update_columns(finished_at: Time.current, result: result)
    end
end
