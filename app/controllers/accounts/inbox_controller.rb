module Accounts
  class InboxController < ApplicationController
    before_action :require_account_access!
    PAGE_SIZE = 25

    def index
      conversations = scoped_conversations.limit(PAGE_SIZE + 1).to_a
      @next_cursor = encode_cursor(conversations[PAGE_SIZE - 1]) if conversations.size > PAGE_SIZE
      @conversations = conversations.first(PAGE_SIZE)
    end

    private

    def scoped_conversations
      scope = current_account.conversations.active
        .includes(:customer, :owner, :current_stage)
        .select("conversations.*, (SELECT content FROM messages WHERE messages.conversation_id = conversations.id ORDER BY messages.created_at DESC, messages.id DESC LIMIT 1) AS latest_message_content")
        .order(Arel.sql("COALESCE(conversations.last_activity_at, conversations.created_at) DESC"), id: :desc)

      # Filter by ownership
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
  end
end
