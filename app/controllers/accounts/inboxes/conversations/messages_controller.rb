module Accounts
  module Inboxes
    module Conversations
      class MessagesController < ApplicationController
        before_action :require_account_access!
        before_action :set_conversation

        # GET /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/messages
        def index
          @messages = @conversation.messages.chronological.includes(:agent)
        end

        # POST /a/:account_id/inboxes/:inbox_id/conversations/:conversation_id/messages
        def create
          Messages::Create.call(
            conversation: @conversation,
            agent:        current_membership.agent,
            content:      params[:content],
            direction:    "outbound"
          )
          redirect_to conversation_return_path
        rescue ActiveRecord::RecordInvalid => e
          redirect_to conversation_return_path, alert: e.message
        end

        private

        def set_conversation
          @conversation = current_account.conversations.find(params[:conversation_id])
        rescue ActiveRecord::RecordNotFound
          redirect_to account_inbox_path(current_account), alert: "Conversation not found."
        end

        def conversation_return_path
          account_inbox_conversation_url(current_account, params[:inbox_id], @conversation)
        end
      end
    end
  end
end