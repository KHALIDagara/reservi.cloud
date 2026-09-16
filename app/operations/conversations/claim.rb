module Conversations
  # Allows an Agent to claim ownership of an unowned Conversation.
  # Race-safe: only one claim succeeds (locked on Conversation row).
  class Claim
    def self.call(conversation:, agent:)
      new(conversation:, agent:).call
    end

    def initialize(conversation:, agent:)
      @conversation = conversation
      @agent = agent
    end

    def call
      @conversation.with_lock do
        raise Reservi::Errors::OperationError, "This conversation already has an owner." if @conversation.owner_id.present?

        @conversation.update!(owner: @agent)
        @conversation
      end
    end
  end
end
