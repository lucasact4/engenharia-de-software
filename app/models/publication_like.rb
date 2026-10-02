
class PublicationLike < ApplicationRecord
  belongs_to :user
  belongs_to :publication

  validates :publication_id, uniqueness: { scope: :user_id }
end
