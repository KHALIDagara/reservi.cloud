module Appointments
  # Marks an appointment as completed. Can be called on pending or confirmed
  # appointments. Does not change Flow state — appointment lifecycle is
  # separate from process lifecycle (INV-010, INV-051).
  class Complete
    def self.call(appointment:)
      new(appointment:).call
    end

    def initialize(appointment:)
      @appointment = appointment
    end

    def call
      raise Reservi::Errors::OperationError, "Appointment is already completed." if @appointment.completed?
      raise Reservi::Errors::OperationError, "Cannot complete a cancelled appointment." if @appointment.cancelled?

      @appointment.transaction do
        @appointment.update!(status: "completed", completed_at: Time.current)
      end

      @appointment
    end
  end
end