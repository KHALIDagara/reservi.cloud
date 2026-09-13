module AccountScoping
  extend ActiveSupport::Concern

  included do
    helper_method :current_account, :current_membership
  end

  private

    # Membership is revalidated on every request for scope "/a/:account_id";
    # a revoked/deactivated membership loses access immediately (INV-130).
    def require_account_access!
      Rails.logger.debug "ACCOUNT_SCOPING: account_id=#{params[:account_id]}, user_id=#{Current.user&.id}"
      account = Account.find_by(id: params[:account_id], active: true)
      Rails.logger.debug "ACCOUNT_SCOPING: account=#{account&.id}"
      membership = account && account.memberships.active.find_by(user_id: Current.user&.id)
      Rails.logger.debug "ACCOUNT_SCOPING: membership=#{membership&.id}"

      raise Reservi::Errors::AuthorizationError, "You do not have access to that Account." unless membership

      Current.account = account
      Current.membership = membership
    end

    def current_account
      Current.account
    end

    def current_membership
      Current.membership
    end
end