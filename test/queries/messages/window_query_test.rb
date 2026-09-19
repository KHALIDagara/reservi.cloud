# frozen_string_literal: true

require "test_helper"

module Messages
  class WindowQueryTest < ActiveSupport::TestCase
    setup do
      @conversation = conversations(:alpha_active)

      # Add 5 test messages to ensure we have enough for window testing
      5.times do |i|
        @conversation.messages.create!(
          author_name: "Test Customer",
          content: "Message #{i + 1}",
          direction: (i.even? ? "inbound" : "outbound")
        )
      end
    end

    test "latest returns most recent messages in chronological order" do
      result = WindowQuery.call(conversation: @conversation, mode: :latest, limit: 3)
      assert result.size <= 3
      # Messages should be chronological (oldest first)
      assert result.first.id < result.last.id
    end

    test "before returns older messages in chronological order" do
      all = @conversation.messages.chronological.to_a
      middle = all[2]

      result = WindowQuery.call(
        conversation: @conversation,
        mode: :before,
        cursor_id: middle.id,
        limit: 10
      )

      # All returned messages should have id < middle.id
      assert result.all? { |m| m.id < middle.id }
      # Chronological order
      assert result.first.id < result.last.id unless result.size < 2
    end

    test "after returns newer messages" do
      all = @conversation.messages.chronological.to_a
      middle = all[2]

      result = WindowQuery.call(
        conversation: @conversation,
        mode: :after,
        cursor_id: middle.id
      )

      assert result.all? { |m| m.id > middle.id }
      # Already chronological (after uses ASC)
      assert result.first.id < result.last.id unless result.size < 2
    end

    test "unknown mode raises" do
      assert_raises(ArgumentError) do
        WindowQuery.call(conversation: @conversation, mode: :bogus)
      end
    end
  end
end