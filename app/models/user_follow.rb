# Seguir pessoas exige opt-in: só é possível seguir conta ativa com public_profile = true.

class UserFollow < ApplicationRecord
  belongs_to :follower, class_name: "User", inverse_of: :active_follows
  belongs_to :followed, class_name: "User", inverse_of: :passive_follows

  validates :followed_id, uniqueness: { scope: :follower_id }
  validate :not_self

  scope :visible, lambda {
    where(follower_id: User.active.select(:id))
      .where(followed_id: User.active.where(public_profile: true).select(:id))
  }

  private

    def not_self
      errors.add(:followed, :self_follow) if follower_id.present? && follower_id == followed_id
    end
end
