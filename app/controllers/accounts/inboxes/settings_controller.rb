module Accounts
  module Inboxes
    # Inbox technical settings: provider info, webhook URL, default
    # assignment, and deletion.  Separate from the workspace so the
    # normal inbox experience is the three-column conversation screen.
    class SettingsController < ApplicationController
      before_action :require_account_access!
      before_action :require_admin!
      before_action :set_inbox

      def show
        @assignable_agents = current_account.agents.assignable.order(:name)
        @teams = current_account.teams.active.order(:name)
      end

      private

      def set_inbox
        @inbox = current_account.channels.find(params[:inbox_id])
      end

      def require_admin!
        return if Accounts::Policy.new(current_membership).admin?
        raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage inbox settings."
      end
    end
  end
end