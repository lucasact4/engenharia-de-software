class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :request_ip
  delegate :user, to: :session, allow_nil: true
end
