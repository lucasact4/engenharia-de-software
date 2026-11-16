class AlertNotificationsMailer < ApplicationMailer
  def update(user, alert)
    @alert = alert
    mail to: user.email_address, subject: "Atualização no relato #{@alert.protocol}"
  end

  def nearby(user, alert)
    @publication = alert.publication
    mail to: user.email_address, subject: "Novo alerta público próximo de você"
  end
end
