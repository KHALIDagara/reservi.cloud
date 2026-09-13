module Accounts
  class InboxController < ApplicationController
    before_action :require_account_access!
    PAGE_SIZE = 25

    def index
      @conversations = scoped_conversations
      @next_cursor = @conversations.size > PAGE_SIZE ? @conversations.last.id : nil
    end

    private

    def scoped_conversations
      scope = current_account.conversations.active
        .includes(:customer, :owner)
        .order(last_activity_at: :desc, id: :desc)

      # Filter by ownership
      case params[:filter]
      when "mine"
        scope = scope.owned_by(current_membership.agent.id)
      when "unowned"
        scope = scope.unowned
      when "team"
        scope = scope.for_team(current_membership.agent.teams.pluck(:id))
      end

      scope = scope.where("conversations.id < ?", params[:before].to_i) if params[:before].present?
      scope.limit(PAGE_SIZE + 1)
    end
  end
end