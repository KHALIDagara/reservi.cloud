module Flows
  # Runs the canonical post-mutation Flow protocol: Rules react first, then
  # completion is evaluated against the resulting authoritative state.
  #
  # If any applicable rule action fails, the Stage does NOT advance. This
  # ensures failed automation (send_message, appointment, assignment) does
  # not silently complete the Stage and lose the chance for retry/recovery.
  class Evaluate
    def self.call(conversation:)
      results = Reservi::RuleExecutor.evaluate(conversation:)
      conversation.reload
      failures = results.select { |r| r.status == "failed" }
      unless failures.empty?
        Rails.logger.warn(
          "Flows::Evaluate blocked for conversation #{conversation.id}: " \
          "#{failures.size} rule(s) failed — #{failures.map(&:rule_key).join(', ')}"
        )
        return { advanced: false, transition: nil, complete: false,
                 explanation: "Blocked: #{failures.size} rule(s) failed" }
      end
      Flows::Advance.call(conversation:)
    end
  end
end
