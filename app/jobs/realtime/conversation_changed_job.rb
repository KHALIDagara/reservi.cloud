# frozen_string_literal: true

# Broadcasts a consolidated realtime update after a domain operation
# (message create, field update, appointment book, assign, etc.) commits.
#
# One logical action → one realtime bundle.
#
# The job reloads latest persisted state before rendering to prevent
# stale out-of-order broadcasts from overwriting newer state.
#
# Uses standard signed Turbo::StreamsChannel for compatibility and security.
# Subscribers (erb templates) and broadcasters (this job) must use the same
# stream name: [account, inbox] for list rows, [account, conversation] for details.
#
# event: :message_created | :field_changed | :item_selected |
#        :appointment_changed | :stage_advanced | :assignment_changed | :read
#
module Realtime
  class ConversationChangedJob < ApplicationJob
    queue_as :realtime

    def perform(account_id:, conversation_id:, revision:, event:, actor_id: nil)
      account      = Account.find(account_id)
      conversation = account.conversations.find(conversation_id)

      # Skip if revision is stale (out-of-order delivery)
      return if conversation.revision.to_i > revision.to_i

      # Find which inboxes this conversation is in
      inbox_ids = conversation.channel_threads.pluck(:channel_id)
      return if inbox_ids.empty?

      # Broadcast to each inbox
      inbox_ids.each do |inbox_id|
        inbox = account.channels.find(inbox_id)

        # Update conversation list row — use viewer-agnostic broadcast
        # so every agent viewing this inbox sees the row update.
        if row_update_event?(event)
          broadcast_inbox_row(inbox:, conversation:, event:)
        end

        # Update open conversation detail
        if detail_event?(event)
          broadcast_conversation_detail(account:, conversation:, event:)
        end
      end
    end

    private

    # -- Inbox list row --------------------------------------------------
    # Broadcast to [account, inbox] — everyone viewing the inbox sees it.
    # One broadcast, not per-agent fan-out.
    #
    # Removes the old row then prepends the updated row so the list
    # stays ordered by last_activity_at DESC.

    def broadcast_inbox_row(inbox:, conversation:, event:)
      html = render_conversation_row(inbox:, conversation:)
      return unless html

      target_id = "conversation_#{conversation.id}"

      Turbo::StreamsChannel.broadcast_remove_to(
        [inbox.account, inbox],
        target: target_id
      )

      Turbo::StreamsChannel.broadcast_prepend_to(
        [inbox.account, inbox],
        target: "conversations_list",
        html:
      )
    end

    def render_conversation_row(inbox:, conversation:)
      # Pick any active human agent to query through the ConversationListQuery
      agent = inbox.account.agents.human.active.first
      return unless agent

      query = Inboxes::ConversationListQuery.call(
        inbox:, agent:
      ).where(id: conversation.id)

      row = query.first
      return unless row

      ApplicationController.render(
        partial: "accounts/inboxes/conversations/conversation_row",
        locals: { conversation: row, selected_id: nil, filter: nil },
        layout: false
      )
    end

    # -- Detail updates --------------------------------------------------
    # Broadcast to [account, conversation] — everyone viewing the conversation
    # detail sees the update (not just the owner).

    def broadcast_conversation_detail(account:, conversation:, event:)
      case event
      when :message_created
        message = conversation.messages.order(id: :desc).first
        return unless message

        html = ApplicationController.render(
          partial: "accounts/inboxes/conversations/messages/message",
          locals: { message: },
          layout: false
        )

        Turbo::StreamsChannel.broadcast_append_to(
          [account, conversation],
          target: "messages_frame",
          html:
        )

      when :stage_advanced, :field_changed, :item_selected,
           :appointment_changed, :assignment_changed
        # Reload conversation to pick up new panel state
        conversation.reload

        html = ApplicationController.render(
          partial: "accounts/inboxes/conversations/panel/show",
          locals: panel_locals_for(conversation),
          layout: false
        )

        Turbo::StreamsChannel.broadcast_replace_to(
          [account, conversation],
          target: "conversation_panel",
          html:
        )
      end
    end

    # -- Helpers ---------------------------------------------------------

    def row_update_event?(event)
      true  # All events update row (activity time, stage, etc.)
    end

    def detail_event?(event)
      %i[
        message_created
        stage_advanced
        field_changed
        item_selected
        appointment_changed
        assignment_changed
      ].include?(event)
    end

    def panel_locals_for(conversation)
      AccountPanelLoader.new(conversation).call
    end

    # -- Panel loader (deduplicated from PanelController) ----------------

    class AccountPanelLoader
      def initialize(conversation)
        @conversation = conversation
        @account = conversation.account
      end

      def call
        @stage = @conversation.current_stage
        @stage_blocks = @stage&.blocks || []

        {
          stage: @stage,
          conversation: @conversation,
          stage_blocks: @stage_blocks,
          customer_fields: load_customer_fields,
          conversation_fields: load_conversation_fields,
          catalogs: load_catalogs,
          item_selections: @conversation.item_selections.index_by(&:role_key),
          catalog_roles: load_catalog_roles,
          appointments: load_appointments,
          account_agents: @account.agents.assignable.order(:name),
          stage_history: @conversation.stage_transitions
            .includes(:from_stage, :to_stage)
            .order(created_at: :asc)
        }
      end

      private

      def field_keys
        @stage_blocks.select { |b| b["type"] == "field" }.map { |b| b["key"] }.compact
      end

      def definitions
        @definitions ||= begin
          keys = field_keys
          return [] if keys.empty?
          @account.field_definitions.active
            .where(scope: %w[customer conversation], key: keys)
            .ordered
        end
      end

      def load_customer_fields
        fields = {}
        definitions.each do |fd|
          next unless fd.scope == "customer"
          key = fd.key
          value = fd.built_in_binding.present? ?
            @conversation.customer.public_send(fd.built_in_binding) :
            @conversation.customer.custom_values[key]
          fields[key] = { definition: fd, value: }
        end
        fields
      end

      def load_conversation_fields
        fields = {}
        definitions.each do |fd|
          next unless fd.scope == "conversation"
          key = fd.key
          fields[key] = { definition: fd, value: @conversation.custom_values[key] }
        end
        fields
      end

      def load_catalogs
        blocks = @stage_blocks.select { |b| b["type"] == "catalog" && b["catalog_key"].present? }
        return [] if blocks.empty?
        keys = blocks.map { |b| b["catalog_key"] }.uniq
        @account.catalogs.active
          .where("LOWER(title) IN (?)", keys.map(&:downcase))
          .includes(:items)
      end

      def load_catalog_roles
        roles = {}
        @stage_blocks.select { |b| b["type"] == "catalog" && b["catalog_key"].present? }.each do |b|
          next unless b["role_key"].present? && b["catalog_key"].present?
          roles[b["role_key"]] = b["catalog_key"]
        end
        roles
      end

      def load_appointments
        blocks = @stage_blocks.select { |b| b["type"] == "appointment" && b["role_key"].present? }
        return {} if blocks.empty?
        role_keys = blocks.map { |b| b["role_key"] }
        @conversation.appointments
          .where(role_key: role_keys)
          .where("superseded_by_id IS NULL OR superseded_by_id = 0")
          .index_by(&:role_key)
      end
    end
  end
end