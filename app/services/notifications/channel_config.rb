module Notifications
  module ChannelConfig
    module_function

    def vapid
      {
        public_key: ENV["SGU_VAPID_PUBLIC_KEY"],
        private_key: ENV["SGU_VAPID_PRIVATE_KEY"],
        subject: ENV["SGU_VAPID_SUBJECT"]
      }
    end

    def push_available? = vapid.values.all?(&:present?)

    def email_available?
      Rails.env.local? || (ENV["SGU_SMTP_ADDRESS"].present? && ENV["SGU_NOTIFICATION_FROM"].present?)
    end
  end
end
