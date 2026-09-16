module AiRuns
  # Transitions an active AiRun to a final state: "completed" or "failed".
  #
  # Uses AiRun#transition_to! which performs an atomic compare-and-set
  # update to prevent race conditions between workers.
  class Complete
    def self.call(ai_run:, status: "completed")
      new(ai_run:, status:).call
    end

    def initialize(ai_run:, status: "completed")
      @ai_run = ai_run
      @status = status
    end

    def call
      raise Reservi::Errors::OperationError, "AiRun is not active" unless @ai_run.active?

      case @status
      when "completed"
        @ai_run.transition_to!("completed")
      when "failed"
        @ai_run.transition_to!("failed")
      else
        raise ArgumentError, "Invalid final status: #{@status}"
      end

      @ai_run
    end
  end
end
