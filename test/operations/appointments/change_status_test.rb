require "test_helper"

class AppointmentsChangeStatusTest < ActiveSupport::TestCase
  setup do
    @account      = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @owner        = agents(:alpha_alice_human)
    @scheduled    = agents(:alpha_bob_human)
    @other        = agents(:alpha_alice_human)

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
      starts_at: Time.utc(2026, 9, 14, 10, 0), duration_minutes: 60,
      operation_key: "status-setup"
    )
  end

  test "cancels a confirmed appointment" do
    result = Appointments::ChangeStatus.call(
      appointment: @appointment, actor: @other,
      status: "cancelled", reason: "No longer needed"
    )
    assert result.cancelled?
    assert_equal "No longer needed", result.cancellation_reason
  end

  test "completes an appointment" do
    result = Appointments::ChangeStatus.call(
      appointment: @appointment, actor: @other,
      status: "completed"
    )
    assert result.completed?
    assert_not_nil result.completed_at
  end

  test "records status_change event" do
    result = Appointments::ChangeStatus.call(
      appointment: @appointment, actor: @other,
      status: "cancelled"
    )
    events = result.appointment_events.where(action: "status_changed")
    assert_equal 1, events.count
  end

  test "rejects change on terminal status" do
    @appointment.update!(status: "cancelled")
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::ChangeStatus.call(
        appointment: @appointment, actor: @other,
        status: "confirmed"
      )
    end
  end

  test "stale expected_version fails" do
    stale = Appointment.find(@appointment.id)
    stale.update_columns(lock_version: 99)
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::ChangeStatus.call(
        appointment: stale, actor: @other,
        status: "cancelled", expected_version: 0
      )
    end
  end
end