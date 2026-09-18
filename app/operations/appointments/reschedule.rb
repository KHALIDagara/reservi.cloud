module Appointments
  # Reschedules a confirmed appointment. Only the Conversation owner may change
  # the day/time.  The operation is atomic: if the new time is invalid or
  # unavailable the original appointment is preserved.
  #
  # Usage:
  #   Appointments::Reschedule.call(
  #     appointment:    appointment,
  #     actor:          current_membership.agent,
  #     starts_at:      new_utc_time,
  #     duration_minutes: 60,
  #     expected_version: appointment.lock_version
  #   )
  class Reschedule
    def self.call(appointment:, actor:, starts_at:, duration_minutes:, expected_version: nil)
      new(appointment:, actor:, starts_at:, duration_minutes:, expected_version:).call
    end

    def initialize(appointment:, actor:, starts_at:, duration_minutes:, expected_version: nil)
      @appointment     = appointment
      @actor           = actor
      @starts_at       = starts_at
      @duration_minutes = duration_minutes
      @expected_version = expected_version
    end

    VALID_DURATIONS = (15..480).step(15).to_a.freeze

    def call
      raise Reservi::Errors::OperationError, "Only confirmed appointments can be rescheduled" unless @appointment.confirmed?
      raise Reservi::Errors::OperationError, "Actor is not schedulable" unless @actor.schedulable?

      unless @appointment.conversation.owner_id == @actor.id
        raise Reservi::Errors::OperationError, "Only the conversation owner can reschedule appointments"
      end

      unless VALID_DURATIONS.include?(@duration_minutes)
        raise Reservi::Errors::OperationError, "Duration must be 15–480 minutes in 15-minute steps"
      end

      ends_at = @starts_at + @duration_minutes.minutes

      # Check availability against the scheduled Agent's calendar
      if @appointment.scheduled_agent
        setting = @appointment.scheduled_agent.calendar_setting
        unless setting
          raise Reservi::Errors::OperationError, "Scheduled agent has no calendar configured"
        end

        unless setting.available?(starts_at: @starts_at, ends_at: ends_at, exclude_appointment: @appointment)
          raise Reservi::Errors::OperationError, "The selected time is not available"
        end
      end

      before_state = @appointment.attributes.slice("starts_at", "ends_at", "duration_minutes", "status", "lock_version")

      @appointment.transaction do
        @appointment.with_lock do
          if @expected_version && @appointment.lock_version != @expected_version
            raise Reservi::Errors::OperationError, "Appointment was modified by another operation — refresh and try again."
          end

          @appointment.update!(
            starts_at:        @starts_at,
            ends_at:          ends_at,
            duration_minutes: @duration_minutes
          )

          after_state = @appointment.attributes.slice("starts_at", "ends_at", "duration_minutes", "lock_version")
          @appointment.record_event!(
            action: "rescheduled",
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
          "This time conflicts with an existing confirmed appointment."
      end
      raise
    end
  end
end