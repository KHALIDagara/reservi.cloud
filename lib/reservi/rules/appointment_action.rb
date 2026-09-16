module Reservi
  module Rules
    # Creates or confirms an Appointment from a Rule action.
    #
    # Config:
    #   { "type" => "create_appointment",
    #     "role_key" => "site_visit",
    #     "starts_at" => "2026-09-15 14:00:00 UTC",
    #     "duration_minutes" => 60,
    #     "timezone" => "Africa/Casablanca",
    #     "scheduled_agent" => { "agent_name" => "Alice Admin" },
    #     "purpose" => "Initial site visit" }
    #
    #   { "type" => "confirm_appointment",
    #     "role_key" => "site_visit" }
    #
    # Predicates/actions for appointments use the stable role_key to identify
    # which appointment in the conversation context.
    class AppointmentAction
      def self.call(action_config, conversation:, context:)
        new(action_config, conversation:, context:).call
      end

      def initialize(action_config, conversation:, context:)
        @action_config = action_config
        @conversation = conversation
        @context = context
      end

      def call
        case @action_config["type"]
        when "create_appointment"
          create_appointment
        when "confirm_appointment"
          confirm_appointment
        when "cancel_appointment"
          cancel_appointment
        else
          { type: @action_config["type"], status: "failed", error: "Unknown appointment action type" }
        end
      end

      private

      def create_appointment
        role_key = @action_config["role_key"]
        return { type: "create_appointment", status: "failed", error: "Missing role_key" } unless role_key

        starts_at = Time.parse(@action_config["starts_at"])
        ends_at = starts_at + (@action_config["duration_minutes"] || 60).minutes
        timezone = @action_config["timezone"] || "UTC"

        agent = resolve_agent(@action_config["scheduled_agent"]) if @action_config["scheduled_agent"]

        appointment = Appointments::Create.call(
          conversation: @conversation,
          role_key: role_key,
          starts_at: starts_at,
          ends_at: ends_at,
          timezone: timezone,
          scheduled_agent: agent,
          purpose: @action_config["purpose"]
        )

        { type: "create_appointment", status: "created", role_key: role_key,
          appointment_id: appointment.id, starts_at: starts_at.to_s }
      rescue => e
        { type: "create_appointment", status: "failed", error: e.message }
      end

      def confirm_appointment
        role_key = @action_config["role_key"]
        return { type: "confirm_appointment", status: "failed", error: "Missing role_key" } unless role_key

        appointment = @conversation.appointments.current.for_role(role_key).first
        return { type: "confirm_appointment", status: "failed", error: "No appointment found for role" } unless appointment

        Appointments::Confirm.call(appointment: appointment)

        { type: "confirm_appointment", status: "confirmed", role_key: role_key,
          appointment_id: appointment.id }
      rescue Reservi::Errors::OperationError => e
        { type: "confirm_appointment", status: "failed", error: e.message }
      end

      def cancel_appointment
        role_key = @action_config["role_key"]
        return { type: "cancel_appointment", status: "failed", error: "Missing role_key" } unless role_key

        appointment = @conversation.appointments.current.for_role(role_key).first
        return { type: "cancel_appointment", status: "failed", error: "No appointment found for role" } unless appointment

        Appointments::Cancel.call(appointment: appointment, reason: @action_config["reason"])

        { type: "cancel_appointment", status: "cancelled", role_key: role_key }
      rescue Reservi::Errors::OperationError => e
        { type: "cancel_appointment", status: "failed", error: e.message }
      end

      def resolve_agent(config)
        return nil unless config
        if config["agent_name"]
          @conversation.account.agents.active.human.find_by(name: config["agent_name"])
        elsif config["agent_id"]
          @conversation.account.agents.active.human.find_by(id: config["agent_id"])
        end
      end
    end
  end
end
