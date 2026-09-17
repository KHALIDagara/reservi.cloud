module Accounts
  class HomeController < ApplicationController
    before_action :require_account_access!

    def show
      active_conversations = current_account.conversations.active
      @active_count = active_conversations.count
      @attention_count = active_conversations.where(attention: true).count
      @unowned_count = active_conversations.unowned.count
      @mine_count = active_conversations.owned_by(current_membership.agent.id).count
      @recent_conversations = active_conversations
        .includes(:customer, :owner, :current_stage)
        .order(Arel.sql("COALESCE(conversations.last_activity_at, conversations.created_at) DESC"), id: :desc)
        .limit(5)
    end
  end
end
