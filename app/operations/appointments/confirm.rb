module Appointments
  # Confirms a pending Appointment. When a scheduled_agent is set, the
  # PostgreSQL exclusion constraint (no_overlapping_confirmed_appointments)
  # prevents double-booking: two concurrent confirmations for the same
  # Agent with overlapping intervals cannot both succeed.
  class Confirm
    def self.call(appointment:)
      new(appointment:).call
    end

    def initialize(appointment:)
      @appointment = appointment
    end

    def call
      raise Reservi::Errors::OperationError, "Appointment is not pending." unless @appointment.pending?

      @appointment.transaction do
        @appointment.update!(status: "confirmed")
      end

      @appointment
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("no_overlapping_confirmed_appointments")
        raise Reservi::Errors::OperationError,
          "This time conflicts with an existing confirmed appointment for the scheduled agent."
      end
      raise
    end
  end
end