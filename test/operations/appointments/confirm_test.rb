require "test_helper"

class Appointments::ConfirmTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @alice = agents(:alpha_alice_human)
    @agent_b = agents(:alpha_bob_human)

    @starts_at = Time.zone.parse("2026-09-15 14:00:00 UTC")
    @ends_at = Time.zone.parse("2026-09-15 15:00:00 UTC")

    # Create a pending appointment with agent
    @appointment = @conversation.appointments.create!(
      account: @account,
      role_key: "site_visit",
      starts_at: @starts_at,
      ends_at: @ends_at,
      duration_minutes: 60,
      timezone: "UTC",
      scheduled_agent: @alice,
      status: "pending"
    )
  end

  test "confirms a pending appointment" do
    result = Appointments::Confirm.call(appointment: @appointment)
    assert_equal "confirmed", result.status
  end

  test "cannot confirm a completed appointment" do
    @appointment.update!(status: "completed")
    assert_raises(Reservi::Errors::OperationError, match: /not pending/) do
      Appointments::Confirm.call(appointment: @appointment)
    end
  end

  test "cannot confirm a cancelled appointment" do
    @appointment.update!(status: "cancelled")
    assert_raises(Reservi::Errors::OperationError, match: /not pending/) do
      Appointments::Confirm.call(appointment: @appointment)
    end
  end

  test "exclusion constraint prevents overlapping confirmed appointments for same agent" do
    # Confirm the first appointment
    Appointments::Confirm.call(appointment: @appointment)

    # Create another appointment overlapping the same agent's schedule
    overlapping = @conversation.appointments.create!(
      account: @account,
      role_key: "pickup",
      starts_at: @starts_at.advance(minutes: 30),
      ends_at: @ends_at.advance(minutes: 30),
      duration_minutes: 60,
      timezone: "UTC",
      scheduled_agent: @alice,
      status: "pending"
    )

    assert_raises(Reservi::Errors::OperationError, match: /conflict/) do
      Appointments::Confirm.call(appointment: overlapping)
    end
  end

  test "adjacent non-overlapping appointments can coexist" do
    Appointments::Confirm.call(appointment: @appointment)

    adjacent = @conversation.appointments.create!(
      account: @account,
      role_key: "follow_up",
      starts_at: @ends_at,  # starts exactly when first ends — half-open [start, end) so no overlap
      ends_at: @ends_at.advance(hours: 1),
      duration_minutes: 60,
      timezone: "UTC",
      scheduled_agent: @alice,
      status: "pending"
    )

    result = Appointments::Confirm.call(appointment: adjacent)
    assert_equal "confirmed", result.status
  end

  test "different agents can have overlapping appointments" do
    Appointments::Confirm.call(appointment: @appointment)

    other_agent = @conversation.appointments.create!(
      account: @account,
      role_key: "inspection",
      starts_at: @starts_at.advance(minutes: 30),
      ends_at: @ends_at.advance(minutes: 30),
      duration_minutes: 60,
      timezone: "UTC",
      scheduled_agent: @agent_b,
      status: "pending"
    )

    result = Appointments::Confirm.call(appointment: other_agent)
    assert_equal "confirmed", result.status
  end

  test "same agent non-overlapping in same conversation is fine" do
    Appointments::Confirm.call(appointment: @appointment)

    earlier = @conversation.appointments.create!(
      account: @account,
      role_key: "morning_visit",
      starts_at: @starts_at.advance(hours: -3),
      ends_at: @starts_at.advance(hours: -2),
      duration_minutes: 60,
      timezone: "UTC",
      scheduled_agent: @alice,
      status: "pending"
    )

    result = Appointments::Confirm.call(appointment: earlier)
    assert_equal "confirmed", result.status
  end
end