module Appointments
  # Cancels an appointment. Releases the time slot for the scheduled agent.
  # Preserves the appointment record with cancellation metadata — does not
  # delete it. A cancelled appointment can become current for its role
  # until a new appointment supersedes it.
  class Cancel
    def self.call(appointment:, reason: nil)
      new(appointment:, reason:).call
    end

    def initialize(appointment:, reason: nil)
      @appointment = appointment
      @reason = reason
    end

    def call
      raise Reservi::Errors::OperationError, "Appointment is already cancelled." if @appointment.cancelled?
      raise Reservi::Errors::OperationError, "Appointment is already completed." if @appointment.completed?

      @appointment.transaction do
        @appointment.update!(
          status: "cancelled",
          cancellation_reason: @reason,
          cancelled_at: Time.current
        )
      end

      @appointment
    end
  end
end
