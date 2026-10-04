# Assunto da ocorrência. Não define severidade, prioridade, status nem audiência.
class Category < ApplicationRecord
  include CatalogEntry

  has_many :alerts, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 80 }
  validates :description, length: { maximum: 500 }
  validate :details_rule_preserved_when_in_use, on: :update

  def in_use?
    alerts.exists?
  end

  private

    # Mudar a exigência de detalhamento alteraria o significado de alertas já registrados.
    def details_rule_preserved_when_in_use
      errors.add(:requires_details, :in_use) if will_save_change_to_requires_details? && in_use?
    end
end
