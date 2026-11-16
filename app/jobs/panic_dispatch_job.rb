class PanicDispatchJob < ApplicationJob
  queue_as :critical
  self.enqueue_after_transaction_commit = true

  def perform(alert_id)
    alert = Alert.panic.find_by(id: alert_id)
    return unless alert

    recipients = PanicRecipientsQuery.new(alert).call
    recipients.each do |recipient|
      PanicAlertMailer.emergency(alert, recipient).deliver_later(queue: :critical, priority: -100)
      recipient.security_push_subscriptions.find_each do |subscription|
        PanicPushJob.set(priority: -100).perform_later(alert.id, subscription.id)
      end
    end
  end
end
