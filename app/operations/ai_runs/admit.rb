module AiRuns
  # Atomically reserves capacity for an AI run on a Conversation.
  #
  # Race-safe: uses conversation.lock! (SELECT FOR UPDATE) so
  # concurrent admission attempts see the first winner and skip.
  #
  # Preconditions:
  #   - Agent must be operational (active or paused).
  #   - Conversation must be active.
  #
  # Idempotent: returns { status: "skipped" } when an active
  # run already exists for this Conversation.
  class Admit
    def self.call(agent:, conversation:, trigger:)
      new(agent:, conversation:, trigger:).call
    end

    def initialize(agent:, conversation:, trigger:)
      @agent        = agent
      @conversation = conversation
      @trigger      = trigger
    end

    def call
      raise Reservi::Errors::OperationError, "Agent is not operational" unless @agent.operational?
      raise Reservi::Errors::OperationError, "Conversation is not active" unless @conversation.active?

      if AiRun.active.for_conversation(@conversation).exists?
        return { status: "skipped", reason: "Active run already exists" }
      end

      token = SecureRandom.hex(16)

      run = @conversation.transaction do
        @conversation.lock!

        if AiRun.active.for_conversation(@conversation).exists?
          raise ActiveRecord::Rollback
        end

        account = @conversation.account
        account.increment!(:admission_counter)

        AiRun.create!(
          account:                account,
          conversation:           @conversation,
          agent:                  @agent,
          agent_configuration_id: @agent.agent_configuration_id,
          status:                 "admitted",
          trigger:                @trigger,
          admission_token:        token,
          conversation_revision:  @conversation.revision
        )
      end

      if run.nil? || run.id.nil?
        return { status: "skipped", reason: "Active run already exists" }
      end

      { status: "admitted", ai_run_id: run.id, token: token }
    end
  end
end