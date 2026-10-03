# Comportamento comum aos catálogos relacionais (papéis, categorias e locais).

module CatalogEntry
  extend ActiveSupport::Concern

  CODE_FORMAT = /\A[a-z][a-z0-9_]{1,39}\z/

  included do
    normalizes :code, with: ->(code) { code.strip.downcase }
    normalizes :name, with: ->(name) { name.strip }

    validates :code, presence: true, format: { with: CODE_FORMAT }, uniqueness: true
    validates :position, numericality: { only_integer: true }
    validate :code_preserved_when_in_use, on: :update

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :name) }
  end

  # Entrada já referenciada mantém o código: históricos, relatórios e o bootstrap dependem dele.
  # Para mudar o significado, desative a entrada e crie outra.
  def in_use?
    false
  end

  private

    def code_preserved_when_in_use
      errors.add(:code, :in_use) if will_save_change_to_code? && in_use?
    end
end
