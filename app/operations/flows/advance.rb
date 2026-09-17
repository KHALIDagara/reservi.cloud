module Flows
  # Evaluates the current Stage's completion predicate and advances the
  # Conversation to the next Stage if complete. Race-safe: uses Conversation
  # row lock and unique entry_identity to prevent double advancement.
  #
  # Returns { advanced: true/false, transition: StageTransition/nil, explanation: {...} }
  class Advance
    ENTRY_IDENTITY_PREFIX = "stage_entry"

    def self.call(conversation:)
      new(conversation:).call
    end

    def initialize(conversation:)
      @conversation = conversation
    end

    def call
      @conversation.with_lock do
        @conversation.reload
        return already_advanced_result unless @conversation.active?

        result = Reservi::FlowEvaluator.evaluate(@conversation)
        return result_with_explanation(result) unless result[:complete]

        current_stage = @conversation.current_stage
        next_stage = find_next_stage(current_stage)

        entry_identity = generate_entry_identity(current_stage)

        # Guard: double-advance prevention
        if StageTransition.exists?(conversation_id: @conversation.id, entry_identity: entry_identity)
          return already_advanced_result
        end

        next_entry_id = "#{@conversation.id}_#{next_stage&.id || 'terminal'}_#{Time.current.to_i}"

        transition = @conversation.stage_transitions.create!(
          from_stage: current_stage,
          to_stage: next_stage,
          entry_identity: entry_identity,
          reason: "completion",
          input_revisions: {
            profile_revision: @conversation.customer&.profile_revision
          }
        )

        if next_stage
          @conversation.update!(
            current_stage: next_stage,
            stage_entry_id: next_entry_id,
            last_activity_at: Time.current
          )
        else
          # Terminal stage — complete the conversation
          @conversation.update!(
            process_status: "completed",
            stage_entry_id: nil,
            owner: nil,
            attention: false,
            last_activity_at: Time.current
          )
        end

        { advanced: true, transition: transition,
          complete: @conversation.process_status == "completed",
          explanation: result[:explanation] }
      end.tap do |result|
        # Evaluate rules for the new stage after releasing the lock.
        # Rules are independent of the transition lock — they call domain
        # operations that acquire their own locks.
        evaluate_rules if result[:advanced] && !result[:complete]
      end
    end

    private

    def find_next_stage(stage)
      @conversation.flow_version.stages
        .where("position > ?", stage.position)
        .order(position: :asc)
        .first
    end

    def generate_entry_identity(stage)
      "#{ENTRY_IDENTITY_PREFIX}_#{@conversation.id}_#{stage.id}_#{Time.current.to_i}"
    end

    def already_advanced_result
      { advanced: false, transition: nil, complete: @conversation.process_status == "completed",
        explanation: { result: false, reason: "Already advanced or not active" } }
    end

    def result_with_explanation(result)
      { advanced: false, transition: nil,
        complete: false,
        explanation: result[:explanation] }
    end

    def evaluate_rules
      @conversation.reload
      Reservi::RuleExecutor.evaluate(conversation: @conversation)
    rescue => e
      Rails.logger.warn "Rule evaluation failed for conversation #{@conversation.id}: #{e.message}"
      # Rule evaluation failures do not block progression
    end
  end
end
