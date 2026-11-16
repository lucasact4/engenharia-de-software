class PanicAlertMailer < ApplicationMailer
  def emergency(alert, recipient)
    @alert = alert
    @recipient = recipient
    host = Rails.application.config.action_mailer.default_url_options.fetch(:host, "localhost:3000")
    @handling_url = Rails.application.routes.url_helpers.handling_alert_url(alert, host: host)
    message = mail(to: recipient.email_address,
                   from: ENV.fetch("SGU_NOTIFICATION_FROM", "notifications@example.test"),
                   subject: "🚨 EMERGÊNCIA · Pedido de pânico #{@alert.protocol}")
    message["X-Priority"] = "1"
    message["Importance"] = "high"
    message
  end
end
