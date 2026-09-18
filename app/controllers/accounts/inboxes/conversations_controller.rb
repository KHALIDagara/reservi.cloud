module Accounts
  module Inboxes
    # The conversation collection and individual conversation within an inbox.
    # Replaces the old InboxController#scoped_conversations and the
    # ConversationsController conversation workspace actions.
    class ConversationsController < ApplicationController
      before_action :require_account_access!
      before_action :set_inbox
      before_action :set_conversation, only: %i[show]

      PAGE_SIZE = 25

      # GET /a/:account_id/inboxes/:inbox_id/conversations
      def index
        conversations = scoped_conversations.limit(PAGE_SIZE + 1).to_a
        @next_cursor = encode_cursor(conversations[PAGE_SIZE - 1]) if conversations.size > PAGE_SIZE
        @conversations = conversations.first(PAGE_SIZE)
      end

      # GET /a/:account_id/inboxes/:inbox_id/conversations/:id
      def show
        @messages = @conversation.messages.chronological.includes(:agent)
        @notes    = @conversation.notes.chronological.includes(:agent)
        @panel_open = params[:panel] == "open"
        touch_read_cursor!
      end

      private

      def set_inbox
        @inbox = current_account.channels.find(params[:inbox_id])
      end

      def set_conversation
        @conversation = current_account.conversations.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        redirect_to account_inbox_path(current_account), alert: "Conversation not found."
      end

      def scoped_conversations
        scope = current_account.conversations.active
          .includes(:customer, :owner, :current_stage)
          .select("conversations.*, (SELECT content FROM messages WHERE messages.conversation_id = conversations.id ORDER BY messages.created_at DESC, messages.id DESC LIMIT 1) AS latest_message_content")
          .order(Arel.sql("COALESCE(conversations.last_activity_at, conversations.created_at) DESC"), id: :desc)

        case params[:filter]
        when "mine"
          scope = scope.owned_by(current_membership.agent.id)
        when "unowned"
          scope = scope.unowned
        when "team"
          scope = scope.for_team(current_membership.agent.teams.pluck(:id))
        end

        if params[:before].present? && (cursor = decode_cursor(params[:before]))
          scope = scope.where(
            "COALESCE(conversations.last_activity_at, conversations.created_at) < :time OR (COALESCE(conversations.last_activity_at, conversations.created_at) = :time AND conversations.id < :id)",
            time: cursor.fetch("time"), id: cursor.fetch("id")
          )
        end
        scope
      end

      def encode_cursor(conversation)
        Base64.urlsafe_encode64(
          { time: (conversation.last_activity_at || conversation.created_at).iso8601(6), id: conversation.id }.to_json,
          padding: false
        )
      end

      def decode_cursor(cursor)
        parsed = JSON.parse(Base64.urlsafe_decode64(cursor))
        return unless parsed["time"].present? && parsed["id"].present?
        { "time" => Time.iso8601(parsed["time"].to_s), "id" => Integer(parsed["id"].to_s, 10) }
      rescue ArgumentError, JSON::ParserError, TypeError
        nil
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