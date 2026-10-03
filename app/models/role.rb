# Papel institucional declarado. Uma pessoa pode ter vários papéis (ex.: estudante e morador).
# Os códigos reconhecidos são fixos; não há CRUD livre de papéis nem papel "admin".

class Role < ApplicationRecord
  include CatalogEntry

  RECOGNIZED_CODES = %w[security coordination professor student staff visitor resident].freeze

  has_many :user_roles, dependent: :restrict_with_exception
  has_many :users, through: :user_roles

  validates :name, presence: true, length: { maximum: 80 }

  # Códigos reconhecidos nunca mudam: o acesso depende deles.
  def in_use?
    RECOGNIZED_CODES.include?(code_in_database) || user_roles.exists?
  end
end
