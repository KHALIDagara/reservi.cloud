module Reservi
  # Evaluates all Rules on a Stage and executes applicable Actions.
  #
  # Protocol (per rule):
  #   1. Generate a stable execution_key from conversation + stage + rule_key.
  #   2. Skip if already executed (execution_key uniqueness guard — INV-022).
  #   3. Evaluate rule predicate using PredicateEvaluator.
  #   4. If predicate is true, execute each action in order within a transaction.
  #   5. Record a RuleExecution record with results.
  #
  # If any action fails, the entire rule's actions are rolled back, the RuleExecution
  # is recorded with status "failed", and progression pauses. An explicit retry or
  # re-evaluation is needed after the condition is corrected (INV-023).
  class RuleExecutor
    def self.evaluate(conversation:)
      new(conversation).evaluate
    end

    def initialize(conversation)
      @conversation = conversation
    end

    # Evaluates rules for the conversation's current stage.
    # Returns an array of RuleExecution records (newly created or skipped).
    def evaluate
      stage = @conversation.current_stage
      return [] unless stage

      rules = stage.rules
      return [] if rules.blank?

      context = build_context
      results = []

      rules.each do |rule|
        rule_key = rule["key"] || "rule_#{rules.index(rule)}"
        execution_key = generate_execution_key(stage, rule_key)

        # Idempotency guard: skip if this exact rule execution already happened
        if RuleExecution.exists?(execution_key: execution_key)
          results << RuleExecution.find_by(execution_key: execution_key)
          next
        end

        predicate = rule["predicate"]
        predicate_result = if predicate.present?
          PredicateEvaluator.evaluate(predicate, context)
        else
          # Rules without predicates always trigger (default: always-match)
          true
        end

        explanation = build_explanation(rule, predicate_result, predicate, context)

        if predicate_result
          execution = execute_rule_actions(
            stage:, rule:, rule_key:, execution_key:,
            predicate_result:, explanation:, context:
          )
          results << execution
        else
          execution = record_skipped(
            stage:, rule_key:, execution_key:,
            predicate_result:, explanation:
          )
          results << execution
        end
      end

      results
    end

    private

    def build_context
      {
        customer: @conversation.customer,
        conversation: @conversation,
        owner_id: @conversation.owner_id,
        team_id: @conversation.team_id,
        executing_agent: nil  # No executing agent for automated rules
      }
    end

    def generate_execution_key(stage, rule_key)
      "#{stage.id}_#{rule_key}_#{@conversation.id}_#{@conversation.updated_at.to_i}"
    end

    def build_explanation(rule, result, predicate, context)
      if predicate.blank?
        "Rule '#{rule['key']}': no predicate, always executes"
      else
        explanation_tree = PredicateEvaluator.evaluate_with_explanation(predicate, context)
        status = result ? "matched" : "did not match"
        "Rule '#{rule['key']}': predicate #{status} — #{explanation_tree[:reason]}"
      end
    end

    def execute_rule_actions(stage:, rule:, rule_key:, execution_key:,
                             predicate_result:, explanation:, context:)
      actions = rule["actions"] || []
      executed = []

      @conversation.transaction do
        actions.each do |action_config|
          result = execute_action(action_config, context)
          executed << result

          if result[:status] == "failed"
            raise Reservi::Errors::OperationError,
              "Action '#{action_config['type']}' failed: #{result[:error]}"
          end
        end

        record = @conversation.rule_executions.create!(
          stage: stage,
          rule_key: rule_key,
          execution_key: execution_key,
          predicate_result: predicate_result,
          status: "executed",
          actions_executed: executed,
          explanation: explanation
        )

        record
      end
    rescue ActiveRecord::RecordInvalid, Reservi::Errors::OperationError => e
      # Rollback happened; record the failure
      RuleExecution.create!(
        conversation: @conversation,
        stage: stage,
        rule_key: rule_key,
        execution_key: execution_key + "_failed",
        predicate_result: predicate_result,
        status: "failed",
        actions_executed: executed,
        error_message: e.message,
        explanation: explanation
      )
    end

    def record_skipped(stage:, rule_key:, execution_key:, predicate_result:, explanation:)
      @conversation.rule_executions.create!(
        stage: stage,
        rule_key: rule_key,
        execution_key: execution_key,
        predicate_result: predicate_result,
        status: "skipped",
        actions_executed: [],
        explanation: explanation
      )
    end

    def execute_action(action_config, context)
      case action_config["type"]
      when "assign"
        Rules::AssignAction.call(action_config, conversation: @conversation, context: context)
      when "create_appointment", "confirm_appointment", "cancel_appointment"
        Rules::AppointmentAction.call(action_config, conversation: @conversation, context: context)
      when "send_message"
        Rules::SendMessageAction.call(action_config, conversation: @conversation, context: context)
      else
        { type: action_config["type"], status: "failed", error: "Unknown action type: #{action_config['type']}" }
      end
    rescue => e
      { type: action_config["type"], status: "failed", error: e.message }
    end
  end
end