require "test_helper"

class AppointmentsReassignTest < ActiveSupport::TestCase
  setup do
    @account      = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @owner        = agents(:alpha_alice_human)
    @scheduled    = agents(:alpha_bob_human)
    @new_agent    = agents(:alpha_dora_human)

    # Make Dora active and give her calendar
    @new_agent.update!(active: true, operational_status: "active")
    @new_agent.membership.update!(active: true)
    Calendar::SaveSettings.call(
      agent: @new_agent, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]] }
    )

    Calendar::SaveSettings.call(
      agent: @scheduled, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]] }
    )

    @conversation.current_stage.update!(blocks: [
      { "type" => "appointment", "role_key" => "site_visit" }
    ])

    @appointment = Appointments::Book.call(
      conversation: @conversation, actor: @owner,
      scheduled_agent: @scheduled, role_key: "site_visit",
      starts_at: Time.utc(2026, 9, 14, 10, 0), duration_minutes: 60,
      operation_key: "reassign-setup"
    )
  end

  test "reassigns to another agent without conversation ownership" do
    reassigner = agents(:alpha_bob_human) # not the owner
    result = Appointments::Reassign.call(
      appointment: @appointment, actor: reassigner,
      scheduled_agent: @new_agent
    )
    assert_equal @new_agent.id, result.scheduled_agent_id
  end

  test "records reassign event" do
    result = Appointments::Reassign.call(
      appointment: @appointment, actor: @scheduled,
      scheduled_agent: @new_agent
    )
    events = result.appointment_events.where(action: "reassigned")
    assert_equal 1, events.count
  end

  test "rejects reassign to same agent as no-op but returns" do
    result = Appointments::Reassign.call(
      appointment: @appointment, actor: @scheduled,
      scheduled_agent: @scheduled
    )
    assert_equal @scheduled.id, result.scheduled_agent_id
  end

  test "rejects unavailable target agent" do
    # Add a second role so we can book a conflicting slot
    @conversation.current_stage.update!(blocks: [
      { "type" => "appointment", "role_key" => "site_visit" },
      { "type" => "appointment", "role_key" => "other_role" }
    ])
    Appointments::Book.call(
      conversation: @conversation, actor: @owner,
      scheduled_agent: @new_agent, role_key: "other_role",
      starts_at: Time.utc(2026, 9, 14, 10, 0), duration_minutes: 60,
      operation_key: "block-target-rr"
    )
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Reassign.call(
        appointment: @appointment, actor: @scheduled,
        scheduled_agent: @new_agent
      )
    end
  end

  test "stale expected_version fails" do
    stale = Appointment.find(@appointment.id)
    stale.update_columns(lock_version: 99)
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Reassign.call(
        appointment: stale, actor: @scheduled,
        scheduled_agent: @new_agent, expected_version: 0
      )
    end
  end
end