class AlertUpdateNotificationJob < ApplicationJob
  def perform(alert_id)
    alert = Alert.includes(:author, :alert_subscriptions, :publication).find_by(id: alert_id)
    return unless alert

    users = [ alert.author, *alert.alert_subscriptions.map(&:user) ].compact.uniq(&:id)
    users.each do |user|
      next unless user.email_notifications_consented?
      next unless AlertPolicy.new(user, alert).show?

      AlertNotificationsMailer.update(user, alert).deliver_now
    end
  end
end
