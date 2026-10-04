# Entrada pública do cadastro; apenas papéis sem poderes de atendimento podem ser escolhidos.
class Registration
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks
  before_validation :normalize_fields

  attribute :display_name, :string
  attribute :email_address, :string
  attribute :role_code, :string
  attribute :password, :string
  attribute :password_confirmation, :string

  validates :display_name, presence: true, length: { maximum: 80 }
  validates :email_address, presence: true, length: { maximum: 254 }, format: { with: /\A[a-z0-9.!#$%&'*+\/=?^_`{|}~-]+@ufrpe\.br\z/i, message: "deve usar o domínio exatamente @ufrpe.br" }
  validates :role_code, inclusion: { in: User::REGISTRATION_ROLES, message: "deve ser visitante, professor ou estudante" }
  validates :password_confirmation, presence: true
  validates :password, confirmation: true
  validate :strong_password
  validate :email_available

  def normalized_email
    email_address.to_s.strip.downcase
  end

  private

    def normalize_fields
      self.email_address = normalized_email
      self.display_name = display_name.to_s.squish
      self.role_code = role_code.to_s.strip
    end

    def strong_password
      PasswordRequirements.errors(password).each { |message| errors.add(:password, message) }
    end

    def email_available
      errors.add(:email_address, "já está em uso") if User.exists?(email_address: normalized_email)
    end
end
