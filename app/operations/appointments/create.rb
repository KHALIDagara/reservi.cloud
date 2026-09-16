module Appointments
  # Creates a new pending Appointment for a Conversation with a given role_key.
  # If a current (non-superseded) appointment exists for the same role,
  # it is superseded (marked as replaced by the new one).
  #
  # No Catalog or Item selection required (INV-051).
  class Create
    def self.call(conversation:, role_key:, starts_at:, ends_at:, timezone:,
                  scheduled_agent: nil, purpose: nil)
      new(conversation:, role_key:, starts_at:, ends_at:, timezone:,
        scheduled_agent:, purpose:).call
    end

    def initialize(conversation:, role_key:, starts_at:, ends_at:, timezone:,
                   scheduled_agent: nil, purpose: nil)
      @conversation = conversation
      @role_key = role_key
      @starts_at = starts_at
      @ends_at = ends_at
      @timezone = timezone
      @scheduled_agent = scheduled_agent
      @purpose = purpose
    end

    def call
      @conversation.transaction do
        # Remove existing current appointment from the "current" scope by
        # setting superseded_by_id. Use a two-step approach: reserve a
        # placeholder ID by creating the new appointment first outside the
        # unique partial index constraint, then link the old one. The unique
        # partial index only applies where superseded_by_id IS NULL, so we
        # must ensure only one record has NULL at any time.
        existing = @conversation.appointments.current.for_role(@role_key).first

        if existing
          # Temporarily remove from current scope (set non-null placeholder)
          existing.update_column(:superseded_by_id, 0)
        end

        duration = ((@ends_at - @starts_at) / 60).to_i

        appointment = @conversation.appointments.create!(
          account: @conversation.account,
          role_key: @role_key,
          starts_at: @starts_at,
          ends_at: @ends_at,
          duration_minutes: duration,
          timezone: @timezone,
          scheduled_agent: @scheduled_agent,
          purpose: @purpose,
          status: "pending"
        )

        # Mark old appointment as superseded by the new one
        if existing
          existing.update!(superseded_by_id: appointment.id)
        end

        appointment
      end
    end
  end
end
