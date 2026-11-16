class Session < ApplicationRecord
  encrypts :ip_address, :user_agent
  belongs_to :user
  has_many :push_subscriptions, dependent: :delete_all
end
