class PushSubscription < ApplicationRecord
  PROVIDERS = %w[fcm.googleapis.com updates.push.services.mozilla.com web.push.apple.com notify.windows.com].freeze

  belongs_to :session
  encrypts :endpoint, :p256dh, :auth

  validates :endpoint, length: { in: 1..2048 }
  validate :valid_subscription

  def self.allowed_endpoint?(endpoint)
    uri = URI.parse(endpoint.to_s)
    return false unless uri.is_a?(URI::HTTPS) && uri.port == 443 && uri.userinfo.nil? && uri.fragment.nil? && uri.path.present?

    PROVIDERS.any? { |host| uri.host == host || (host.in?(%w[web.push.apple.com notify.windows.com]) && uri.host&.end_with?(".#{host}")) }
  rescue URI::InvalidURIError
    false
  end

  def self.register!(session:, endpoint:, p256dh:, auth:)
    digest = Digest::SHA256.hexdigest(endpoint.to_s)
    subscription = create_or_find_by!(endpoint_digest: digest) do |record|
      record.assign_attributes(session: session, endpoint: endpoint, p256dh: p256dh, auth: auth)
    end
    # Endpoint já associado a outra sessão só pode ser substituído se o navegador apresentar a chave correspondente.
    if subscription.persisted? && subscription.session_id != session.id &&
        !ActiveSupport::SecurityUtils.secure_compare(subscription.auth, auth.to_s)
      raise ActiveRecord::RecordNotFound
    end

    subscription.update!(session: session, endpoint: endpoint, p256dh: p256dh, auth: auth)
    subscription
  end

  private

    def valid_subscription
      errors.add(:endpoint, :invalid) unless self.class.allowed_endpoint?(endpoint)
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
