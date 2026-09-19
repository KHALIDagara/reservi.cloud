# frozen_string_literal: true

require "test_helper"

module Inboxes
  class ConversationListQueryTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:alpha)
      @agent   = agents(:alpha_alice_human)
      @channel = channels(:alpha_dev)

      # Link the fixture conversation to this channel if not already linked
      @conversation = conversations(:alpha_active)
      @channel.channel_threads.find_or_create_by!(
        account: @account,
        conversation: @conversation,
        external_thread_id: "fixture-test-#{@conversation.id}"
      ) do |ct|
        ct.external_contact_name = "Wilma Push"
      end
    end

    test "returns virtual attributes for each conversation row" do
      result = ConversationListQuery.call(
        inbox: @channel,
        agent: @agent
      ).limit(5).to_a

      refute_empty result, "should find at least one conversation"
      row = result.find { |r| r.id == @conversation.id }
      assert row, "should find the fixture conversation"

      # Customer display
      assert_equal "Wilma Push", row.push_name, "push_name should come from channel_thread"
      assert row.customer_name.present?
      assert row.customer_initial.present?

      # Activity
      assert row.last_activity.present?
      assert row.attention

      # Stage / owner
      assert_equal "Intake", row.stage_label
      assert_equal "Alice Admin", row.owner_name
    end

    test "does not error on empty inbox" do
      empty_channel = @account.channels.create!(
        name: "Empty",
        provider_type: "dev",
        inbound_token: SecureRandom.urlsafe_base64(32)
      )

      result = ConversationListQuery.call(
        inbox: empty_channel,
        agent: @agent
      ).to_a

      assert_equal [], result
    end

    test "filters by mine" do
      result = ConversationListQuery.call(
        inbox: @channel,
        agent: @agent,
        filter: "mine"
      ).to_a

      assert result.all? { |r| r.owner_id == @agent.id },
        "mine filter should only return conversations owned by the agent"
    end

    test "filters by unowned" do
      @conversation.update!(owner_id: nil)

      result = ConversationListQuery.call(
        inbox: @channel,
        agent: @agent,
        filter: "unowned"
      ).to_a

      assert result.any?,
        "should find the now-unowned conversation"
      assert result.all? { |r| r.owner_id.nil? },
        "unowned filter should only return conversations with no owner"
    end

    test "encode/decode cursor round-trip" do
      rows = ConversationListQuery.call(
        inbox: @channel,
        agent: @agent
      ).limit(1).to_a

      return skip("no conversations to test cursor") if rows.empty?

      row = rows.first
      encoded = ConversationListQuery.encode_cursor(row)
      decoded = ConversationListQuery.decode_cursor(encoded)

      assert decoded
      assert_equal row.id, decoded["id"]
    end

    test "decode_cursor returns nil for junk" do
      assert_nil ConversationListQuery.decode_cursor("not-valid-base64!!!")
      assert_nil ConversationListQuery.decode_cursor("")
      assert_nil ConversationListQuery.decode_cursor(nil)
    end
  end
end