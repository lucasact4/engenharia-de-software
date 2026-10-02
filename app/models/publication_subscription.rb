# Acompanhamento da conversa e de avisos de uma publicação (diferente de favorito).

class PublicationSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :publication

  validates :publication_id, uniqueness: { scope: :user_id }
end
