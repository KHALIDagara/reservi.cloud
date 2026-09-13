class Current < ActiveSupport::CurrentAttributes
  attribute :session, :account, :membership
  delegate :user, to: :session, allow_nil: true
end