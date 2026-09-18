module Appointments
  # Changes the status of an appointment (confirm, cancel, complete, no_show).
  # Any active Account member can change the status. Terminal statuses
  # (cancelled, completed, no_show) cannot be changed further.
  #
  # Cancellation/completion/no_show releases the booked capacity.
  #
  # Usage:
  #   Appointments::ChangeStatus.call(
  #     appointment:      appointment,
  #     actor:            current_membership.agent,
  #     status:           "cancelled",
  #     reason:           "Customer rescheduled",
  #     expected_version: appointment.lock_version
  #   )
  class ChangeStatus
    def self.call(appointment:, actor:, status:, reason: nil, expected_version: nil)
      new(appointment:, actor:, status:, reason:, expected_version:).call
    end

    def initialize(appointment:, actor:, status:, reason: nil, expected_version: nil)
      @appointment      = appointment
      @actor            = actor
      @status           = status
      @reason           = reason
      @expected_version = expected_version
    end

    TERMINAL = %w[cancelled completed no_show].freeze
    ALLOWED = %w[confirmed cancelled completed no_show].freeze

    def call
      raise Reservi::Errors::OperationError, "Actor must be an active Account member" unless @actor.active? && @actor.kind == "human"
      raise Reservi::Errors::OperationError, "Invalid status" unless ALLOWED.include?(@status)

      if @appointment.terminal?
        raise Reservi::Errors::OperationError, "Cannot change a #{@appointment.status} appointment"
      end

      before_state = @appointment.attributes.slice("status", "cancellation_reason", "cancelled_at", "completed_at", "lock_version")

      @appointment.transaction do
        @appointment.with_lock do
          if @expected_version && @appointment.lock_version != @expected_version
            raise Reservi::Errors::OperationError, "Appointment was modified by another operation — refresh and try again."
          end

          attrs = { status: @status }

          case @status
          when "cancelled"
            attrs[:cancellation_reason] = @reason
            attrs[:cancelled_at]        = Time.current
          when "completed"
            attrs[:completed_at] = Time.current
          end

          @appointment.update!(attrs)

          after_state = @appointment.attributes.slice("status", "cancellation_reason", "cancelled_at", "completed_at", "lock_version")
          @appointment.record_event!(
            action: (@status == "confirmed" ? "confirmed" : "status_changed"),
            actor: @actor,
            before_state: before_state,
            after_state: after_state
          )
        end
      end

      @appointment
    end
  end
end