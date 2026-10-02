# Acompanhamento do atendimento de um Alert. Não concede acesso: consultas revalidam AlertPolicy.

class AlertSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :alert

  validates :alert_id, uniqueness: { scope: :user_id }
end
