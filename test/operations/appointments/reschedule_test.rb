require "test_helper"

class AppointmentsRescheduleTest < ActiveSupport::TestCase
  setup do
    @account      = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @owner        = agents(:alpha_alice_human)
    @scheduled    = agents(:alpha_bob_human)
    @starts_at    = Time.utc(2026, 9, 14, 10, 0)

    @conversation.current_stage.update!(blocks: [
      { "type" => "appointment", "role_key" => "site_visit" }
    ])

    Calendar::SaveSettings.call(
      agent: @scheduled, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]] }
    )

    @appointment = Appointments::Book.call(
      conversation: @conversation, actor: @owner,
      scheduled_agent: @scheduled, role_key: "site_visit",
      starts_at: @starts_at, duration_minutes: 60,
      operation_key: "resched-setup"
    )
  end

  test "reschedules to a new available time" do
    new_start = Time.utc(2026, 9, 14, 14, 0)
    result = Appointments::Reschedule.call(
      appointment: @appointment, actor: @owner,
      starts_at: new_start, duration_minutes: 60
    )
    assert_equal new_start, result.starts_at
    assert_equal 60, result.duration_minutes
  end

  test "records a reschedule event" do
    result = Appointments::Reschedule.call(
      appointment: @appointment, actor: @owner,
      starts_at: Time.utc(2026, 9, 14, 15, 0), duration_minutes: 60
    )
    events = result.appointment_events.where(action: "rescheduled")
    assert_equal 1, events.count
  end

  test "rejects non-owner reschedule" do
    not_owner = agents(:alpha_bob_human)
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Reschedule.call(
        appointment: @appointment, actor: not_owner,
        starts_at: Time.utc(2026, 9, 14, 16, 0), duration_minutes: 60
      )
    end
  end

  test "stale expected version fails" do
    stale = Appointment.find(@appointment.id)
    stale.update_columns(lock_version: 99)
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Reschedule.call(
        appointment: stale, actor: @owner,
        starts_at: Time.utc(2026, 9, 14, 15, 0), duration_minutes: 60,
        expected_version: 0
      )
    end
  end

  test "rejects unavailable new time" do
    # Add an extra role for the blocking booking
    @conversation.current_stage.update!(blocks: [
      { "type" => "appointment", "role_key" => "site_visit" },
      { "type" => "appointment", "role_key" => "other_role" }
    ])
    Appointments::Book.call(
      conversation: @conversation, actor: @owner,
      scheduled_agent: @scheduled, role_key: "other_role",
      starts_at: Time.utc(2026, 9, 14, 15, 0), duration_minutes: 60,
      operation_key: "block-resched-2"
    )
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Reschedule.call(
        appointment: @appointment, actor: @owner,
        starts_at: Time.utc(2026, 9, 14, 15, 0), duration_minutes: 60
      )
    end
    @appointment.reload
    assert_equal @starts_at, @appointment.starts_at # preserved
  end
end