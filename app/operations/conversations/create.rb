module Conversations
  # Atomically creates a Customer (or finds existing by email), a Conversation
  # pinned to the Account's default FlowVersion, and an initial Message.
  # Returns the newly-created Conversation.
  class Create
    def self.call(account:, customer_attributes:, agent:, content:, team_id: nil)
      new(account:, customer_attributes:, agent:, content:, team_id:).call
    end

    def initialize(account:, customer_attributes:, agent:, content:, team_id:)
      @account = account
      @customer_attributes = customer_attributes
      @agent = agent
      @content = content
      @team_id = team_id
    end

    def call
      flow_version = find_default_flow_version!

      Account.transaction do
        customer = find_or_create_customer!
        stage = flow_version.stages.order(:position).first!
        conversation = @account.conversations.create!(
          customer:,
          flow_version:,
          current_stage: stage,
          process_status: "active",
          owner: @agent,
          team_id: @team_id,
          attention: true,
          first_attention_at: Time.current,
          last_activity_at: Time.current
        )
        conversation.messages.create!(
          agent: @agent,
          author_name: @agent.name,
          content: @content,
          direction: "inbound",
          delivery_status: "local"
        )
        conversation
      end
    end

    private

    def find_default_flow_version!
      flow = @account.flows.first
      raise Reservi::Errors::OperationError, "No Flow configured for this Account." unless flow
      raise Reservi::Errors::OperationError, "Default Flow has no published version." unless flow.current_version

      flow.current_version
    end

    def find_or_create_customer!
      email = @customer_attributes[:email_address].presence
      if email
        @account.customers.find_by(email_address: email) ||
          @account.customers.create!(@customer_attributes)
      else
        @account.customers.create!(@customer_attributes)
      end
    end
  end
end