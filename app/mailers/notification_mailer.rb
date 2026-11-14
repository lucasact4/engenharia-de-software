class NotificationMailer < ApplicationMailer
  def confirm_email(user)
    return if user.email_confirmed_at? || user.deleted_at?

    url = email_confirmation_url(token: user.generate_token_for(:email_confirmation),
                                 protocol: Rails.env.production? ? "https" : "http")
    mail(to: user.email_address, from: ENV.fetch("SGU_NOTIFICATION_FROM", "notifications@example.test"),
         subject: "SGU UFRPE · Confirme seu e-mail",
         body: "Abra o link e confirme seu e-mail. O link expira em 24 horas.\n\n#{url}",
         content_type: "text/plain")
  end

  def notice(delivery)
    @inbox_url = notifications_url(protocol: Rails.env.production? ? "https" : "http")
    mail(to: delivery.notification.user.email_address,
         from: ENV.fetch("SGU_NOTIFICATION_FROM", "notifications@example.test"),
         subject: "SGU UFRPE · Nova notificação",
         message_id: "<sgu-notification-#{delivery.id}@#{URI.parse(@inbox_url).host}>")
  end
end
