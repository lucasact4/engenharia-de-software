class NotificationMailer < ApplicationMailer
  def confirm_email(user)
    return if user.email_confirmed_at? || user.deleted_at?

    @confirmation_url = email_confirmation_url(token: user.generate_token_for(:email_confirmation))
    attach_logo
    mail(to: user.email_address, from: ENV.fetch("SGU_NOTIFICATION_FROM", "notifications@example.test"),
         subject: "SGU UFRPE · Confirme seu e-mail") do |format|
      format.text
      format.html
    end
  end

  def notice(delivery)
    @inbox_url = notifications_url
    post_updated = delivery.notification.kind.in?(%w[alert_status publication_status])
    @heading = post_updated ? "Sua postagem foi atualizada" : "Você tem uma nova notificação"
    attach_logo
    mail(to: delivery.notification.user.email_address,
         from: ENV.fetch("SGU_NOTIFICATION_FROM", "notifications@example.test"),
         subject: "SGU UFRPE · #{@heading}",
         message_id: "<sgu-notification-#{delivery.id}@#{URI.parse(@inbox_url).host}>") do |format|
      format.text
      format.html
    end
  end

  private

  def attach_logo
    attachments.inline["sgu-logo.png"] = Rails.root.join("app/assets/images/brand/sgu-logo-horizontal.png").binread
  end
end
