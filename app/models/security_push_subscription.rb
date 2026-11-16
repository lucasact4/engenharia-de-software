class SecurityPushSubscription < ApplicationRecord
  belongs_to :user
  encrypts :endpoint, :p256dh, :auth

  validates :endpoint, length: { in: 1..2048 }
  validate :valid_subscription

  private

    def valid_subscription
      errors.add(:endpoint, :invalid) unless PushSubscription.allowed_endpoint?(endpoint)
      errors.add(:p256dh, :invalid) unless valid_key?(p256dh, 65, prefix: 4)
      errors.add(:auth, :invalid) unless valid_key?(auth, 16)
    end

    def valid_key?(key, size, prefix: nil)
      return false unless key.to_s.match?(/\A[A-Za-z0-9_-]{1,100}={0,2}\z/)

      decoded = Base64.urlsafe_decode64(key)
      decoded.bytesize == size && (prefix.nil? || decoded.getbyte(0) == prefix)
    rescue ArgumentError
      false
    end
end
