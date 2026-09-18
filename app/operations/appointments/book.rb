module Appointments
  # Books a confirmed Appointment for a human scheduled_agent from a Conversation
  # with a current-Stage role.
  #
  # Always creates a confirmed appointment — there is no separate confirmation
  # step in the collaborative-scheduling product.
  #
  # Usage:
  #   Appointments::Book.call(
  #     conversation: conversation,
  #     actor:          current_membership.agent,
  #     scheduled_agent: selected_agent,
  #     role_key:        "site_visit",
  #     starts_at:       utc_time,
  #     duration_minutes: 60,
  #     operation_key:    "unique-op-key"   # idempotency
  #   )
  #
  # Idempotent: calling with the same operation_key returns the existing record
  # without mutation.  Only the original fields are compared; a changed payload
  # with the same key is rejected as an invalid retry.
  class Book
    def self.call(conversation:, actor:, scheduled_agent:, role_key:, starts_at:, duration_minutes:, operation_key: nil, purpose: nil)
      new(
        conversation: conversation,
        actor: actor,
        scheduled_agent: scheduled_agent,
        role_key: role_key,
        starts_at: starts_at,
        duration_minutes: duration_minutes,
        operation_key: operation_key,
        purpose: purpose
      ).call
    end

    def initialize(conversation:, actor:, scheduled_agent:, role_key:, starts_at:, duration_minutes:, operation_key: nil, purpose: nil)
      @conversation     = conversation
      @actor            = actor
      @scheduled_agent  = scheduled_agent
      @role_key         = role_key
      @starts_at        = starts_at
      @duration_minutes = duration_minutes
      @operation_key    = operation_key
      @purpose          = purpose
    end

    VALID_DURATIONS = (15..480).step(15).to_a.freeze

    def call
      # ── Validate inputs ──────────────────────────────────────────
      raise Reservi::Errors::OperationError, "Role key is required" unless @role_key.present?

      unless VALID_DURATIONS.include?(@duration_minutes)
        raise Reservi::Errors::OperationError, "Duration must be 15–480 minutes in 15-minute steps"
      end

      unless @starts_at.is_a?(Time) || @starts_at.is_a?(ActiveSupport::TimeWithZone)
        raise Reservi::Errors::OperationError, "Invalid start time"
      end

      raise Reservi::Errors::OperationError, "Actor is not schedulable" unless @actor.schedulable?
      raise Reservi::Errors::OperationError, "Scheduled agent is not schedulable" unless @scheduled_agent.schedulable?

      unless @scheduled_agent.account_id == @conversation.account_id
        raise Reservi::Errors::OperationError, "Scheduled agent must belong to the same account"
      end

      # Verify the booked role is exposed by the current stage (ad hoc roles are out of scope here)
      available = Array(@conversation.current_stage&.blocks).any? do |block|
        block["type"] == "appointment" && block["role_key"] == @role_key
      end
      raise Reservi::Errors::OperationError, "That appointment role is not available in the current stage." unless available

      # Ensure the Conversation owner exists (scheduling without an owner is not supported)
      raise Reservi::Errors::OperationError, "Conversation must have an owner to schedule" unless @conversation.owner_id.present?

      # The actor must be the Conversation owner to reschedule/change time
      unless @conversation.owner_id == @actor.id
        raise Reservi::Errors::OperationError, "Only the conversation owner can schedule appointments"
      end

      ends_at = @starts_at + @duration_minutes.minutes
      timezone = @scheduled_agent.calendar_setting&.active_timezone&.name || @conversation.account.timezone || "UTC"

      # ── Idempotency guard through operation_key ──────────────
      if @operation_key.present?
        existing = @conversation.appointments.current.for_role(@role_key).find_by(operation_key: @operation_key)
        if existing
          return existing if existing.starts_at == @starts_at &&
                             existing.duration_minutes == @duration_minutes &&
                             existing.scheduled_agent_id == @scheduled_agent.id &&
                             existing.status == "confirmed"

          raise Reservi::Errors::OperationError, "Duplicate operation key with mismatched payload"
        end
      end

      # ── Availability check (outside transaction) ─────────────
      setting = @scheduled_agent.calendar_setting
      unless setting
        raise Reservi::Errors::OperationError, "#{@scheduled_agent.name} has no calendar configured and cannot be scheduled."
      end

      unless setting.available?(starts_at: @starts_at, ends_at: ends_at)
        raise Reservi::Errors::OperationError, "The selected time is not available for #{@scheduled_agent.name}."
      end

      # ── Locking order: Conversation → sorted Agents → Appointment ─
      appointment = nil
      @conversation.transaction do
        @conversation.with_lock do
          existing = @conversation.appointments.current.for_role(@role_key).first

          if existing
            existing.with_lock do
              existing.update_column(:superseded_by_id, 0)
            end
          end

          appointment = @conversation.appointments.create!(
            account:           @conversation.account,
            role_key:          @role_key,
            starts_at:         @starts_at,
            ends_at:           ends_at,
            duration_minutes:  @duration_minutes,
            timezone:          timezone,
            scheduled_agent:   @scheduled_agent,
            created_by:        @actor,
            purpose:           @purpose,
            operation_key:     @operation_key,
            status:            "confirmed"
          )

          # The exclusion constraint protects against double-booking.
          # If two concurrent bookings race, one will raise PG::ExclusionViolation.

          if existing
            existing.update!(superseded_by_id: appointment.id)
          end

          appointment.record_event!(
            action: "confirmed",
            actor:  @actor,
            before_state: existing&.slice(:starts_at, :ends_at, :scheduled_agent_id, :status) || {},
            after_state:  { starts_at: @starts_at, ends_at: ends_at,
                            scheduled_agent_id: @scheduled_agent.id, status: "confirmed",
                            created_by_id: @actor.id }
          )
        end
      end

      appointment
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("no_overlapping_confirmed_appointments")
        raise Reservi::Errors::OperationError,
          "This time conflicts with an existing confirmed appointment for #{@scheduled_agent.name}."
      end
      raise
    end
  end
end