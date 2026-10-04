# Conta de acesso; perfis institucionais são múltiplos e users.admin define a administração.
class User < ApplicationRecord
  include TextSearch
  USERNAME_FORMAT = /\A[a-z0-9_]{3,30}\z/

  REGISTRATION_ROLES = %w[visitor professor student].freeze

  # Tipos explícitos também permitem executar os testes de atualização a partir do esquema antigo.
  attribute :registration_status, :string, default: "approved"
  attribute :registration_role_code, :string
  enum :registration_status, { pending: "pending", approved: "approved", rejected: "rejected" }, prefix: :registration, validate: true
  belongs_to :registration_reviewed_by, class_name: "User", optional: true

  attribute :verified_at, :datetime
  belongs_to :verified_by, class_name: "User", optional: true

  def verified? = active? && verified_at.present?

  has_one_attached :avatar
  validate :avatar_constraints

  has_secure_password
  has_many :sessions, dependent: :destroy

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
  normalizes :bio, with: ->(bio) { bio.strip.presence }

  validates :email_address, presence: true, uniqueness: true
  validates :registration_role_code, inclusion: { in: REGISTRATION_ROLES }, allow_nil: true
  validate :password_requirements, on: %i[registration password_change]
  validates :password_confirmation, presence: true, on: %i[registration password_change]

  validates :username, format: { with: USERNAME_FORMAT }, uniqueness: true, allow_nil: true
  validates :display_name, length: { maximum: 80 }
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
end
