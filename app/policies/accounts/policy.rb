module Accounts
  # Actor-scoped capability checks over a Membership. See architecture §5 for
  # the role table; AI Agents have no Membership and therefore no policy here.
  class Policy
    def initialize(membership)
      @membership = membership
    end

    def active? = @membership&.active?

    def admin? = active? && @membership.role == "admin"

    def manager? = active? && @membership.manager?

    def member? = active?
  end
end