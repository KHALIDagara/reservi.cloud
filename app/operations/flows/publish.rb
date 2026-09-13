module Flows
  # Validates and publishes a FlowVersion.
  # Once published, a version is immutable.
  # Sets it as the Flow's current_version.
  class Publish
    def self.call(flow_version:, actor_membership:)
      new(flow_version:, actor_membership:).call
    end

    def initialize(flow_version:, actor_membership:)
      @flow_version = flow_version
      @actor_membership = actor_membership
    end

    def call
      raise Reservi::Errors::AuthorizationError, "Only administrators can publish flows." unless admin?
      raise Reservi::Errors::OperationError, "Version is already published." if @flow_version.published?
      raise Reservi::Errors::OperationError, "Version must have at least one stage." if @flow_version.stages.empty?

      # Validate stage structure
      @flow_version.stages.each do |stage|
        validate_stage!(stage)
      end

      @flow_version.transaction do
        @flow_version.update!(status: "published", published_at: Time.current)
        @flow_version.flow.update!(current_version: @flow_version)
        @flow_version
      end
    end

    private

    def admin?
      Accounts::Policy.new(@actor_membership).admin?
    end

    def validate_stage!(stage)
      # Validate blocks reference only implemented types
      stage.blocks.each do |block|
        type = block["type"]
        unless %w[field catalog appointment].include?(type)
          raise Reservi::Errors::OperationError,
            "Stage '#{stage.key}': unsupported block type '#{type}'"
        end
      end

      # Validate rules reference only implemented action types
      stage.rules.each do |rule|
        (rule["actions"] || []).each do |action|
          action_type = action["type"]
          unless %w[assign send_message create_appointment confirm_appointment cancel_appointment].include?(action_type)
            raise Reservi::Errors::OperationError,
              "Stage '#{stage.key}', rule '#{rule['key']}': unsupported action type '#{action_type}'"
          end
        end
      end
    end
  end
end