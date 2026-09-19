# frozen_string_literal: true

module Inboxes
  # Returns the conversation list for an inbox workspace with exactly the data
  # needed by the _conversation row partial.
  #
  # Each row carries:
  #   push_name       – channel_thread.external_contact_name || customer.name
  #   customer_name   – Conversation#customer.name (fallback/display)
  #   customer_initial – first letter of customer name for avatar
  #   latest_message_preview – truncated latest message content
  #   stage_label     – current_stage.label (or nil)
  #   owner_name      – owner.name (or nil)
  #   unread_count    – count of inbound messages newer than the agent's last read cursor
  #   attention       – Conversation#attention boolean
  #   last_activity   – COALESCE(last_activity_at, created_at)
  #   id              – Conversation id (for cursor + routing)
  #
  # Pagination: keyset cursor on (last_activity DESC, id DESC).  No OFFSET.
  #
  class ConversationListQuery
    PAGE_SIZE = 25

    # Returns an ActiveRecord::Relation. The caller chains `.limit` and
    # materialises when ready.
    def self.call(inbox:, agent:, filter: nil, before_cursor: nil)
      new(inbox:, agent:, filter:, before_cursor:).call
    end

    def initialize(inbox:, agent:, filter:, before_cursor:)
      @inbox   = inbox
      @agent   = agent
      @filter  = filter
      @before  = before_cursor
    end

    def call
      scope = base_scope
      scope = apply_filter(scope)
      scope = apply_cursor(scope)
      scope
    end

    # -- cursor helpers (static so controller can reuse them) -----------

    def self.encode_cursor(record)
      time = record[:last_activity] || record.created_at
      Base64.urlsafe_encode64(
        { time: time.iso8601(6), id: record.id }.to_json,
        padding: false
      )
    end

    def self.decode_cursor(cursor)
      return nil if cursor.blank?

      parsed = JSON.parse(Base64.urlsafe_decode64(cursor))
      return unless parsed["time"].present? && parsed["id"].present?

      { "time" => Time.iso8601(parsed["time"].to_s), "id" => Integer(parsed["id"].to_s, 10) }
    rescue ArgumentError, JSON::ParserError, TypeError
      nil
    end

    private

    # -- query assembly -------------------------------------------------

    def base_scope
      # @inbox.conversations already INNER JOINs channel_threads, which
      # gives us the external_contact_name column.  We add LEFT JOINs for
      # owner, current_stage, and the agent's read cursor.
      @inbox.conversations
        .active
        .joins(:customer)
        .joins(<<~SQL.squish)
          LEFT JOIN conversation_reads
            ON conversation_reads.conversation_id = conversations.id
            AND conversation_reads.agent_id = #{@agent.id}
        SQL
        .left_joins(:owner, :current_stage)
        .select(select_list)
        .order(Arel.sql("last_activity DESC"), "conversations.id DESC")
    end

    def select_list
      <<~SQL.squish
        conversations.id,
        conversations.attention,
        conversations.last_activity_at,
        conversations.created_at,
        conversations.owner_id,
        conversations.current_stage_id,
        COALESCE(conversations.last_activity_at, conversations.created_at) AS last_activity,
        customers.name AS customer_name,
        LEFT(customers.name, 1) AS customer_initial,
        COALESCE(
          channel_threads.external_contact_name,
          NULLIF(channel_threads.external_contact_id, ''),
          customers.name
        ) AS push_name,
        stages.label AS stage_label,
        agents.name AS owner_name,
        (
          SELECT content
          FROM messages
          WHERE messages.conversation_id = conversations.id
          ORDER BY messages.created_at DESC, messages.id DESC
          LIMIT 1
        ) AS latest_message_preview,
        (
          SELECT COUNT(*)
          FROM messages
          WHERE messages.conversation_id = conversations.id
            AND messages.direction = 'inbound'
            AND messages.id > COALESCE(conversation_reads.last_read_message_id, 0)
        ) AS unread_count
      SQL
    end

    # -- filter ---------------------------------------------------------

    def apply_filter(scope)
      case @filter
      when "mine"
        scope.where(owner_id: @agent.id)
      when "unowned"
        scope.where(owner_id: nil)
      when "team"
        scope.where(team_id: @agent.teams.select(:id))
      else
        scope
      end
    end

    # -- keyset cursor --------------------------------------------------

    def apply_cursor(scope)
      cursor = self.class.decode_cursor(@before) if @before.present?
      return scope unless cursor

      time = cursor.fetch("time")
      id   = cursor.fetch("id")

      scope.where(<<~SQL.squish, time:, id:)
        COALESCE(conversations.last_activity_at, conversations.created_at) < :time
        OR (
          COALESCE(conversations.last_activity_at, conversations.created_at) = :time
          AND conversations.id < :id
        )
      SQL
    end
  end
end