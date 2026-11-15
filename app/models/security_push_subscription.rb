class SecurityPushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, length: { maximum: 4096 }, format: { with: /\Ahttps:\/\// }
  validates :p256dh, :auth, presence: true
end
