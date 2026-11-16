module Notifications
  module Outbox
    EXTERNAL_KINDS = %w[alert_status publication_status nearby_alert].freeze

    module_function

    def queue(notification)
      return unless EXTERNAL_KINDS.include?(notification.kind)

      if ChannelConfig.email_available? && NotificationPreference.exists?(user_id: notification.user_id, email_enabled: true)
        NotificationDelivery.create!(notification: notification, channel: "email", available_at: Time.current)
      end
      return unless ChannelConfig.push_available?

      PushSubscription.joins(:session).where(sessions: {
        user_id: notification.user_id, created_at: Authentication::SESSION_DURATION.ago..
      }).find_each do |subscription|
        NotificationDelivery.create!(notification: notification, push_subscription: subscription, channel: "push", available_at: Time.current)
      end
    end
  end
end
