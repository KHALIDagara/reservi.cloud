module Appointments
  # Reassigns a confirmed appointment to a different schedulable Agent.
  # Does NOT require Conversation ownership — any active Account member may
  # reassign an appointment within the Account.
  #
  # Checks that the new Agent is schedulable and the existing time interval
  # is available for the new Agent.
  #
  # Usage:
  #   Appointments::Reassign.call(
  #     appointment:      appointment,
  #     actor:            current_membership.agent,
  #     scheduled_agent:  new_agent,
  #     expected_version: appointment.lock_version
  #   )
  class Reassign
    def self.call(appointment:, actor:, scheduled_agent:, expected_version: nil)
      new(appointment:, actor:, scheduled_agent:, expected_version:).call
    end

    def initialize(appointment:, actor:, scheduled_agent:, expected_version: nil)
      @appointment     = appointment
      @actor           = actor
      @scheduled_agent = scheduled_agent
      @expected_version = expected_version
    end

    def call
      raise Reservi::Errors::OperationError, "Only confirmed appointments can be reassigned" unless @appointment.confirmed?
      raise Reservi::Errors::OperationError, "Actor is not schedulable" unless @actor.schedulable?
      raise Reservi::Errors::OperationError, "Target agent is not schedulable" unless @scheduled_agent.schedulable?

      unless @scheduled_agent.account_id == @appointment.account_id
        raise Reservi::Errors::OperationError, "Target agent must belong to the same account"
      end

      # No-op if reassigning to the same Agent
      if @appointment.scheduled_agent_id == @scheduled_agent.id
        return @appointment
      end

      # Check availability on the new Agent's calendar (excluding self from conflict)
      setting = @scheduled_agent.calendar_setting
      unless setting
        raise Reservi::Errors::OperationError, "Target agent has no calendar configured"
      end

      unless setting.available?(starts_at: @appointment.starts_at, ends_at: @appointment.ends_at, exclude_appointment: @appointment)
        raise Reservi::Errors::OperationError, "The selected time is not available for #{@scheduled_agent.name}"
      end

      before_state = @appointment.attributes.slice("scheduled_agent_id", "lock_version")

      @appointment.transaction do
        @appointment.with_lock do
          if @expected_version && @appointment.lock_version != @expected_version
            raise Reservi::Errors::OperationError, "Appointment was modified by another operation — refresh and try again."
          end

          previous_agent_id = @appointment.scheduled_agent_id
          @appointment.update!(
            scheduled_agent: @scheduled_agent
          )

          after_state = @appointment.attributes.slice("scheduled_agent_id", "lock_version")
          @appointment.record_event!(
            action: "reassigned",
            actor: @actor,
            before_state: before_state,
            after_state: after_state
          )
        end
      end

      @appointment
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("no_overlapping_confirmed_appointments")
        raise Reservi::Errors::OperationError,
          "This time conflicts with an existing confirmed appointment for #{@scheduled_agent.name}."
      end
      raise
    end
  end
end