# Conta de acesso; perfis institucionais são múltiplos e users.admin define a administração.
class User < ApplicationRecord
  include TextSearch
  USERNAME_FORMAT = /\A[a-z0-9_]{3,30}\z/
  PERSON_TYPES = %w[natural legal].freeze

  REGISTRATION_ROLES = %w[visitor professor student].freeze

  # Tipos explícitos também permitem executar os testes de atualização a partir do esquema antigo.
  attribute :registration_status, :string, default: "approved"
  attribute :registration_role_code, :string
  attribute :person_type, :string, default: "natural"
  enum :registration_status, { pending: "pending", approved: "approved", rejected: "rejected" }, prefix: :registration, validate: true
  enum :person_type, { natural: "natural", legal: "legal" }, validate: true
  belongs_to :registration_reviewed_by, class_name: "User", optional: true

  attribute :verified_at, :datetime
  belongs_to :verified_by, class_name: "User", optional: true
  attribute :email_notifications_enabled, :boolean, default: false
  attribute :nearby_alerts_email_enabled, :boolean, default: false
  attribute :nearby_alerts_radius_km, :integer, default: 5
  attribute :email_notifications_consented_at, :datetime
  attribute :notification_location_id, :integer
  belongs_to :notification_location, class_name: "Location", optional: true

  before_validation :stamp_email_notification_consent
  validates :nearby_alerts_radius_km, numericality: { only_integer: true, in: 1..25 }
  validate :nearby_notifications_require_consent_and_location

  def verified? = active? && verified_at.present?

  def email_notifications_consented? = email_notifications_enabled? && email_notifications_consented_at.present?

  has_one_attached :avatar
  validate :avatar_constraints

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :notifications, dependent: :destroy

  # Papéis declarados (multiperfil). Não concedem administração: ver Role.
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles

  has_many :authored_alerts, class_name: "Alert", foreign_key: :author_id, inverse_of: :author,
           dependent: :restrict_with_exception
  has_many :assigned_alerts, class_name: "Alert", foreign_key: :assigned_to_id, inverse_of: :assigned_to,
           dependent: :restrict_with_exception
  has_many :authored_publications, class_name: "Publication", foreign_key: :author_id, inverse_of: :author,
           dependent: :restrict_with_exception
  has_many :comments, foreign_key: :author_id, inverse_of: :author, dependent: :restrict_with_exception
  has_many :content_reports, foreign_key: :reporter_id, inverse_of: :reporter, dependent: :restrict_with_exception
  has_many :audit_events, foreign_key: :actor_id, inverse_of: :actor, dependent: :restrict_with_exception

  has_many :publication_likes, dependent: :destroy
  has_many :comment_likes, dependent: :destroy
  has_many :publication_bookmarks, dependent: :destroy
  has_many :publication_subscriptions, dependent: :destroy
  has_many :alert_subscriptions, dependent: :destroy
  has_many :active_follows, class_name: "UserFollow", foreign_key: :follower_id, inverse_of: :follower,
           dependent: :destroy
  has_many :passive_follows, class_name: "UserFollow", foreign_key: :followed_id, inverse_of: :followed,
           dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(username) { username.strip.downcase.presence }
  normalizes :display_name, with: ->(name) { name.squish.presence }
  normalizes :business_name, :mother_name, with: ->(name) { name.squish.presence }
  normalizes :cpf, :cnpj, :phone, with: ->(document) { document.gsub(/\D/, "").presence }
  normalizes :bio, with: ->(bio) { bio.strip.presence }

  # Documentos são determinísticos para permitir busca exata sem persistir o valor aberto.
  encrypts :cpf, :cnpj, :phone, deterministic: true

  validates :email_address, presence: true, uniqueness: true
  validates :registration_role_code, inclusion: { in: REGISTRATION_ROLES }, allow_nil: true
  validate :password_requirements, on: %i[registration password_change]
  validates :password_confirmation, presence: true, on: %i[registration password_change]

  validates :username, format: { with: USERNAME_FORMAT }, uniqueness: true, allow_nil: true
  validates :display_name, length: { maximum: 80 }
  validates :business_name, :mother_name, length: { maximum: 160 }
  validates :cpf, length: { is: 11 }, uniqueness: true, allow_nil: true
  validates :cnpj, length: { is: 14 }, uniqueness: true, allow_nil: true
  validates :phone, length: { in: 10..13 }, uniqueness: true, allow_nil: true
  validate :identity_document_matches_person_type
  validates :bio, length: { maximum: 500 }

  scope :active, -> { where(deleted_at: nil, registration_status: "approved") }

  def active?
    deleted_at.blank? && registration_approved?
  end

  def role?(code)
    code = code.to_s
    return false unless active? && Role::RECOGNIZED_CODES.include?(code)

    roles.active.exists?(code: code)
  end

  private

    def stamp_email_notification_consent
      if email_notifications_enabled?
        self.email_notifications_consented_at ||= Time.current
      else
        self.email_notifications_consented_at = nil
        self.nearby_alerts_email_enabled = false
        self.notification_location = nil
      end
    end

    def nearby_notifications_require_consent_and_location
      return unless nearby_alerts_email_enabled?

      errors.add(:nearby_alerts_email_enabled, "exige consentimento para e-mails") unless email_notifications_enabled?
      errors.add(:notification_location, "selecione um local de referência") unless notification_location
      if notification_location && (!notification_location.active? || notification_location.reference_latitude.nil? || notification_location.reference_longitude.nil?)
        errors.add(:notification_location, "precisa ser ativo e ter coordenadas de referência")
      end
    end

    def avatar_constraints
      change = attachment_changes["avatar"]
      return unless change && change.respond_to?(:blob)

      blob = change.blob
      errors.add(:avatar, "deve ter até 5 MB") if blob.byte_size > Alert::MAX_PHOTO_BYTES
      attachable = change.attachable
      if attachable.is_a?(ActiveStorage::Blob) || attachable.is_a?(String)
        errors.add(:avatar, "envie um novo arquivo")
      elsif !Alert::PHOTO_CONTENT_TYPES.include?(blob.content_type) || Alerts::PhotoUpload.detect(Alerts::PhotoUpload.io_for(attachable)) != blob.content_type
        errors.add(:avatar, "deve ser uma imagem PNG ou JPEG")
      end
    end

    def password_requirements
      PasswordRequirements.errors(password).each { |message| errors.add(:password, message) }
    end

    def identity_document_matches_person_type
      errors.add(:cnpj, :incompatible_person_type) if natural? && cnpj.present?
      errors.add(:cpf, :incompatible_person_type) if legal? && cpf.present?
      errors.add(:business_name, :blank) if legal? && business_name.blank?
    end
end
