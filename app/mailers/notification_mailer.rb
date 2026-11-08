class NotificationMailer < ApplicationMailer
  def notice(delivery)
    @inbox_url = notifications_url(protocol: Rails.env.production? ? "https" : "http")
    mail(to: delivery.notification.user.email_address,
         from: ENV.fetch("SGU_NOTIFICATION_FROM", "notifications@example.test"),
         subject: "SGU UFRPE · Nova notificação",
         message_id: "<sgu-notification-#{delivery.id}@#{URI.parse(@inbox_url).host}>")
  end
end
