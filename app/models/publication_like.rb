
class PublicationLike < ApplicationRecord
  after_create { Notifications::Events.liked(self) }
  belongs_to :user
  belongs_to :publication

  validates :publication_id, uniqueness: { scope: :user_id }
end
