module Reservi
  # Evaluates whether a Conversation's current Stage is complete.
  # Builds the context from the Conversation and evaluates the completion predicate.
  class FlowEvaluator
    def self.evaluate(conversation)
      new(conversation).evaluate
    end

    def initialize(conversation)
      @conversation = conversation
    end

    def evaluate
      stage = @conversation.current_stage
      return { complete: false, explanation: { result: false, reason: "No current stage" } } unless stage

      context = build_context
      predicate = stage.completion.presence || { "literal" => false }
      explanation = PredicateEvaluator.evaluate_with_explanation(predicate, context)

      { complete: explanation[:result], explanation: explanation }
    end

    private

    def build_context
      {
        customer: @conversation.customer,
        conversation: @conversation,
        owner_id: @conversation.owner_id,
        team_id: @conversation.team_id
      }
    end
  end
end
