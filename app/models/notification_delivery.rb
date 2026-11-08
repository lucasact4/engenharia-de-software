class NotificationDelivery < ApplicationRecord
  belongs_to :notification
  belongs_to :push_subscription, optional: true

  scope :due, -> { where(finished_at: nil, available_at: ..Time.current) }
end
