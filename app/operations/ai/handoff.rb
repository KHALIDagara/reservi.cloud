module Ai
  # Pauses an AI agent and releases all its owned conversations back
  # to the unowned queue so human operators can pick them up.
  class Handoff
    def self.call(agent:)
      new(agent:).call
    end

    def initialize(agent:)
      @agent = agent
      raise Reservi::Errors::OperationError, "Agent is not AI" unless @agent.kind == "ai"
    end

    def call
      @agent.transaction do
        @agent.lock!
        raise Reservi::Errors::OperationError, "Agent is not operational" unless @agent.operational?

        conversations  = @agent.owned_conversations.to_a
        unclaimed_count = 0

        conversations.each do |conv|
          Conversations::Unclaim.call(conversation: conv, agent: @agent)
          unclaimed_count += 1
        end

        @agent.update!(operational_status: "paused")

        { status: "paused", unclaimed: unclaimed_count }
      end
    end
  end
end
