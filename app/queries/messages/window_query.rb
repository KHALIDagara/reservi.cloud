# frozen_string_literal: true

module Messages
  # Returns a bounded window of messages for a conversation.
  #
  # Window modes:
  #   :latest  – the most recent N messages (default: 30)
  #   :before  – N messages before the given message ID
  #   :after   – all messages after the given message ID (for reconnect)
  #
  # The resulting array is always in chronological order (oldest first).
  #
  class WindowQuery
    DEFAULT_LIMIT = 30

    # Returns an array of messages, chronological.
    def self.call(conversation:, mode: :latest, cursor_id: nil, limit: DEFAULT_LIMIT)
      new(conversation:, mode:, cursor_id:, limit:).call
    end

    def initialize(conversation:, mode:, cursor_id:, limit:)
      @conversation = conversation
      @mode     = mode
      @cursor   = cursor_id
      @limit    = limit
    end

    def call
      scope = @conversation.messages.includes(:agent)

      scope = case @mode
              when :latest
                scope.reorder("messages.created_at DESC, messages.id DESC").limit(@limit)
              when :before
                scope.where("messages.id < ?", @cursor)
                  .reorder("messages.created_at DESC, messages.id DESC")
                  .limit(@limit)
              when :after
                scope.where("messages.id > ?", @cursor)
                  .reorder("messages.created_at ASC, messages.id ASC")
              else
                raise ArgumentError, "unknown window mode: #{@mode.inspect}"
              end

      # Always return chronological order for display
      result = scope.to_a
      result.reverse! unless @mode == :after
      result
    end
  end
end