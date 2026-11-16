class SecurityPresence < ApplicationRecord
  FRESH_FOR = 5.minutes

  belongs_to :user

  validates :latitude, numericality: { in: -90..90 }
  validates :longitude, numericality: { in: -180..180 }
  validates :reported_at, presence: true

  scope :fresh, -> { where(reported_at: FRESH_FOR.ago..) }
end
