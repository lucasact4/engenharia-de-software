# Metadados de submissões com identidade pública oculta; cifrados com chave derivada
# do secret_key_base e consultados apenas pela tela administrativa.
class AnonymousSubmissionAudit < ApplicationRecord
  belongs_to :alert

  validates :submitted_at, :ip_address_ciphertext, :user_agent_ciphertext, presence: true
  before_update { raise ActiveRecord::ReadOnlyRecord, "anonymous_submission_audits é append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "anonymous_submission_audits é append-only" }

  def readonly? = persisted? || super
  def ip_address = self.class.send(:decrypt, ip_address_ciphertext)
  def user_agent = self.class.send(:decrypt, user_agent_ciphertext)

  def self.record!(alert:, ip_address:, user_agent:, submitted_at:)
    create!(alert: alert, submitted_at: submitted_at,
            ip_address_ciphertext: encrypt(ip_address.to_s),
            user_agent_ciphertext: encrypt(user_agent.to_s))
  end

  def self.encrypt(value) = encryptor.encrypt_and_sign(value)
  def self.decrypt(value) = encryptor.decrypt_and_verify(value)

  def self.encryptor
    key = Rails.application.key_generator.generate_key("sgu-anonymous-submission-audit", 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
  end

  private_class_method :encrypt, :decrypt, :encryptor
end
