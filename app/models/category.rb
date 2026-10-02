# Assunto da ocorrência. Não define severidade, prioridade, status nem audiência.
class Category < ApplicationRecord
  include CatalogEntry

  has_many :alerts, dependent: :restrict_with_exception

  validates :name, presence: true, length: { maximum: 80 }
end
