module Accounts
  module Inboxes
    # The conversation collection and individual conversation within an inbox.
    # Uses Inboxes::ConversationListQuery to produce a rich read model for
    # each row (push name, unread count, stage, assignee, etc).
    class ConversationsController < ApplicationController
      before_action :require_account_access!
      before_action :set_inbox
      before_action :set_conversation, only: %i[show]

      PAGE_SIZE = Inboxes::ConversationListQuery::PAGE_SIZE

      # GET /a/:account_id/inboxes/:inbox_id/conversations
      def index
        conversations = scoped_conversations.limit(PAGE_SIZE + 1).to_a
        @next_cursor = Inboxes::ConversationListQuery.encode_cursor(conversations[PAGE_SIZE - 1]) if conversations.size > PAGE_SIZE
        @conversations = conversations.first(PAGE_SIZE)
      end

      # GET /a/:account_id/inboxes/:inbox_id/conversations/:id
      def show
        @messages = Messages::WindowQuery.call(
          conversation: @conversation,
          mode: :latest,
          limit: 30
        )
        @has_older_messages = @conversation.messages.count > @messages.size
        @oldest_message_id = @messages.first&.id

        @notes    = @conversation.notes.chronological.includes(:agent)
        @panel_open = params[:panel] == "open"
        touch_read_cursor!
      end

      private

      def set_inbox
        @inbox = current_account.channels.find(params[:inbox_id])
      end

      def set_conversation
        @conversation = @inbox.conversations.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        redirect_to account_inbox_path(current_account, @inbox), alert: "Conversation not found."
      end

      def scoped_conversations
        Inboxes::ConversationListQuery.call(
          inbox:          @inbox,
          agent:          current_membership.agent,
          filter:         params[:filter],
          before_cursor:  params[:before]
        )
      end

      def touch_read_cursor!
        read = @conversation.conversation_reads.find_or_initialize_by(agent: current_membership.agent)
        last_message = @conversation.messages.order(id: :desc).first
        if last_message && (read.new_record? || read.last_read_message_id.to_i < last_message.id)
          read.update!(last_read_message_id: last_message.id)
        end
      end
    end
  end
end