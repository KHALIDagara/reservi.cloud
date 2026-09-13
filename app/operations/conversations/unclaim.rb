module Conversations
  # Releases ownership of a Conversation back to the unowned queue.
  # The agent releasing must be the current owner (or an admin via controller).
  class Unclaim
    def self.call(conversation:, agent:)
      new(conversation:, agent:).call
    end

    def initialize(conversation:, agent:)
      @conversation = conversation
      @agent = agent
    end

    def call
      @conversation.with_lock do
        unless @conversation.owner_id == @agent.id
          raise Reservi::Errors::AuthorizationError, "You are not the current owner of this conversation."
        end

        @conversation.update!(owner: nil)
        @conversation
      end
    end
  end
end