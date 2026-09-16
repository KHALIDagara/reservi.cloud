module Conversations
  # Cancels an active Conversation. Records the reason but does not clear
  # attention or send messages — cancellation and attention are separate (T02 §4).
  class Cancel
    def self.call(conversation:, agent:, reason:)
      new(conversation:, agent:, reason:).call
    end

    def initialize(conversation:, agent:, reason:)
      @conversation = conversation
      @agent = agent
      @reason = reason
    end

    def call
      @conversation.with_lock do
        raise Reservi::Errors::OperationError, "This conversation is already #{@conversation.process_status}." unless @conversation.active?

        @conversation.update!(
          process_status: "cancelled",
          owner: nil
        )
        @conversation
      end
    end
  end
end
