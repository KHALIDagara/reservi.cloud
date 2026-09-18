module Conversations
  # Forces possession of a Conversation to the calling actor regardless of
  # current owner state. Intended for explicit takeover from the appointment
  # context (e.g., the operator currently assigned the appointment can claim
  # the Conversation to service it).
  #
  # Usage:
  #   Conversations::Takeover.call(conversation: conversation, actor: current_agent)
  class Takeover
    def self.call(conversation:, actor:)
      new(conversation:, actor:).call
    end

    def initialize(conversation:, actor:)
      @conversation = conversation
      @actor        = actor
    end

    def call
      raise Reservi::Errors::OperationError, "Actor must be an active Account member" unless @actor.active? && @actor.kind == "human"

      @conversation.with_lock do
        # Release existing owner if present
        @conversation.update!(owner: @actor)
        @conversation
      end
    end
  end
end
