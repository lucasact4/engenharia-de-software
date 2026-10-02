# Comportamento comum aos catálogos relacionais (papéis, categorias e locais).

module CatalogEntry
  extend ActiveSupport::Concern

  CODE_FORMAT = /\A[a-z][a-z0-9_]{1,39}\z/

  included do
    normalizes :code, with: ->(code) { code.strip.downcase }
    normalizes :name, with: ->(name) { name.strip }

    validates :code, presence: true, format: { with: CODE_FORMAT }, uniqueness: true
    validates :position, numericality: { only_integer: true }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :name) }
  end
end
