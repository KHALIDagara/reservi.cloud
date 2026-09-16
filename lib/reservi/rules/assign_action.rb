module Reservi
  module Rules
    # Assigns a Conversation to an Agent or Team.
    #
    # Action config:
    #   { "type" => "assign", "agent_name" => "Alice Admin" }
    #   { "type" => "assign", "agent_id" => 1 }
    #   { "type" => "assign", "team_name" => "General" }
    #   { "type" => "assign", "team_id" => 1 }
    #
    # Uses the same Conversations::Claim operation as manual assignment (INV-062).
    # Returns a result hash for the RuleExecution record.
    class AssignAction
      def self.call(action_config, conversation:, context:)
        new(action_config, conversation:, context:).call
      end

      def initialize(action_config, conversation:, context:)
        @action_config = action_config
        @conversation = conversation
        @context = context
      end

      def call
        agent = resolve_agent

        if agent
          Conversations::Claim.call(conversation: @conversation, agent: agent)
          { type: "assign", agent_name: agent.name, agent_id: agent.id, status: "assigned" }
        else
          { type: "assign", status: "skipped", reason: "No eligible agent found" }
        end
      rescue Reservi::Errors::OperationError => e
        { type: "assign", status: "skipped", reason: e.message }
      end

      private

      def resolve_agent
        account = @conversation.account

        if @action_config["agent_id"]
          account.agents.active.find_by(id: @action_config["agent_id"])
        elsif @action_config["agent_name"]
          account.agents.active.find_by(name: @action_config["agent_name"])
        elsif @action_config["team_name"]
          team = account.teams.active.find_by(name: @action_config["team_name"])
          return nil unless team
          pick_agent_from_team(team)
        elsif @action_config["team_id"]
          team = account.teams.active.find_by(id: @action_config["team_id"])
          return nil unless team
          pick_agent_from_team(team)
        end
      end

      def pick_agent_from_team(team)
        # Prefer agents with fewer active conversations (simple round-robin)
        team.agents.active
          .left_joins(:owned_conversations)
          .where(conversations: { process_status: [ nil, "active" ] })
          .group(:id)
          .order(Arel.sql("COUNT(conversations.id) ASC"))
          .first
      end
    end
  end
end
