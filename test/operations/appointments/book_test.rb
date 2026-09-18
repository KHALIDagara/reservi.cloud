require "test_helper"

class AppointmentsBookTest < ActiveSupport::TestCase
  setup do
    @account        = accounts(:alpha)
    @conversation   = conversations(:alpha_active)
    @owner          = agents(:alpha_alice_human)
    @scheduled      = agents(:alpha_bob_human)
    @actor          = agents(:alpha_alice_human)
    @starts_at      = Time.utc(2026, 9, 14, 10, 0)

    # Ensure the stage has an appointment block
    @conversation.current_stage.update!(blocks: [
      { "type" => "appointment", "role_key" => "site_visit" }
    ])

    # Give scheduled agent calendar availability
    Calendar::SaveSettings.call(
      agent: @scheduled,
      timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]] }
    )
  end

  test "books a confirmed appointment" do
    appt = Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at,
      duration_minutes: 60,
      operation_key: "test-book-1"
    )

    assert appt.persisted?
    assert_equal "confirmed", appt.status
    assert_equal @scheduled.id, appt.scheduled_agent_id
    assert_equal @actor.id, appt.created_by_id
    assert_equal "site_visit", appt.role_key
    assert_equal 60, appt.duration_minutes
  end

  test "records an appointment event" do
    appt = Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at,
      duration_minutes: 60,
      operation_key: "test-book-events"
    )
    assert_equal 1, appt.appointment_events.count
    event = appt.appointment_events.first
    assert_equal "confirmed", event.action
    assert_equal @actor.id, event.actor_id
  end

  test "is idempotent with same operation_key" do
    appt1 = Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at,
      duration_minutes: 60,
      operation_key: "idempotent-key"
    )
    appt2 = Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at,
      duration_minutes: 60,
      operation_key: "idempotent-key"
    )
    assert_equal appt1.id, appt2.id
  end

  test "rejects mismatched payload with same operation_key" do
    Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at,
      duration_minutes: 60,
      operation_key: "mismatch-key"
    )
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Book.call(
        conversation: @conversation,
        actor: @actor,
        scheduled_agent: @scheduled,
        role_key: "site_visit",
        starts_at: @starts_at + 1.hour,
        duration_minutes: 90,
        operation_key: "mismatch-key"
      )
    end
  end

  test "rejects unowned conversation" do
    @conversation.update!(owner: nil)
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Book.call(
        conversation: @conversation,
        actor: @actor,
        scheduled_agent: @scheduled,
        role_key: "site_visit",
        starts_at: @starts_at,
        duration_minutes: 60,
        operation_key: "nobody-owns"
      )
    end
  end

  test "only owner can schedule" do
    not_owner = agents(:alpha_bob_human)
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Book.call(
        conversation: @conversation,
        actor: not_owner,
        scheduled_agent: @scheduled,
        role_key: "site_visit",
        starts_at: @starts_at,
        duration_minutes: 60,
        operation_key: "not-owner"
      )
    end
  end

  test "rejects agent with no calendar" do
    unscheduled = agents(:alpha_dora_human)
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Book.call(
        conversation: @conversation,
        actor: @actor,
        scheduled_agent: unscheduled,
        role_key: "site_visit",
        starts_at: @starts_at,
        duration_minutes: 60,
        operation_key: "no-cal"
      )
    end
  end

  test "rejects unavailable time" do
    Calendar::SaveSettings.call(
      agent: @scheduled,
      timezone: "UTC",
      weekly_hours: { "1" => [["14:00", "17:00"]] }
    )
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Book.call(
        conversation: @conversation,
        actor: @actor,
        scheduled_agent: @scheduled,
        role_key: "site_visit",
        starts_at: @starts_at, # 10:00, agent not available
        duration_minutes: 60,
        operation_key: "unavail"
      )
    end
  end

  test "rejects cross-account agent" do
    beta_agent = agents(:beta_alice_human)
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Book.call(
        conversation: @conversation,
        actor: @actor,
        scheduled_agent: beta_agent,
        role_key: "site_visit",
        starts_at: @starts_at,
        duration_minutes: 60,
        operation_key: "cross-acc"
      )
    end
  end

  test "rejects invalid duration" do
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Book.call(
        conversation: @conversation,
        actor: @actor,
        scheduled_agent: @scheduled,
        role_key: "site_visit",
        starts_at: @starts_at,
        duration_minutes: 500,
        operation_key: "bad-duration"
      )
    end
  end

  test "role must be in current stage" do
    @conversation.current_stage.update!(blocks: [])
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Book.call(
        conversation: @conversation,
        actor: @actor,
        scheduled_agent: @scheduled,
        role_key: "site_visit",
        starts_at: @starts_at,
        duration_minutes: 60,
        operation_key: "no-role"
      )
    end
  end

  test "overlapping booking hits exclusion constraint" do
    Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at,
      duration_minutes: 60,
      operation_key: "overlap-1"
    )
    assert_raises(Reservi::Errors::OperationError) do
      Appointments::Book.call(
        conversation: @conversation,
        actor: @actor,
        scheduled_agent: @scheduled,
        role_key: "site_visit",
        starts_at: @starts_at + 30.minutes,
        duration_minutes: 60,
        operation_key: "overlap-2"
      )
    end
  end

  test "adjacent bookings are allowed" do
    Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at,
      duration_minutes: 60,
      operation_key: "adj-1"
    )
    appt2 = Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at + 60.minutes,
      duration_minutes: 60,
      operation_key: "adj-2"
    )
    assert appt2.persisted?
    assert_equal "confirmed", appt2.status
  end

  test "supersedes existing appointment for same role" do
    first = Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at,
      duration_minutes: 60,
      operation_key: "super-1"
    )
    second = Appointments::Book.call(
      conversation: @conversation,
      actor: @actor,
      scheduled_agent: @scheduled,
      role_key: "site_visit",
      starts_at: @starts_at + 2.hours,
      duration_minutes: 60,
      operation_key: "super-2"
    )
    first.reload
    assert_equal second.id, first.superseded_by_id
  end
end