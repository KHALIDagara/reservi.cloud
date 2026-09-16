require "test_helper"

class Appointments::CreateTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @starts_at = Time.zone.parse("2026-09-15 14:00:00 UTC")
    @ends_at = Time.zone.parse("2026-09-15 15:00:00 UTC")
  end

  test "creates a pending appointment" do
    appointment = Appointments::Create.call(
      conversation: @conversation,
      role_key: "site_visit",
      starts_at: @starts_at,
      ends_at: @ends_at,
      timezone: "Africa/Casablanca"
    )

    assert appointment.persisted?
    assert_equal "site_visit", appointment.role_key
    assert_equal "pending", appointment.status
    assert_equal @conversation.id, appointment.conversation_id
    assert_equal 60, appointment.duration_minutes
    assert_equal "Africa/Casablanca", appointment.timezone
  end

  test "creates appointment without Catalog or Item selection" do
    appointment = Appointments::Create.call(
      conversation: @conversation,
      role_key: "inspection",
      starts_at: @starts_at,
      ends_at: @ends_at,
      timezone: "UTC"
    )

    assert appointment.persisted?
    assert_equal "inspection", appointment.role_key
  end

  test "supersedes existing appointment for same role" do
    first = Appointments::Create.call(
      conversation: @conversation,
      role_key: "site_visit",
      starts_at: @starts_at,
      ends_at: @ends_at,
      timezone: "UTC"
    )

    new_starts = Time.zone.parse("2026-09-16 14:00:00 UTC")
    new_ends = Time.zone.parse("2026-09-16 15:00:00 UTC")

    second = Appointments::Create.call(
      conversation: @conversation,
      role_key: "site_visit",
      starts_at: new_starts,
      ends_at: new_ends,
      timezone: "UTC"
    )

    first.reload
    assert_equal second.id, first.superseded_by_id
    assert first.superseded_by.present?

    # Current scope should show only the latest
    current = @conversation.appointments.current.for_role("site_visit")
    assert_equal 1, current.count
    assert_equal second.id, current.first.id
  end

  test "allows multiple roles per conversation" do
    visit = Appointments::Create.call(
      conversation: @conversation,
      role_key: "site_visit",
      starts_at: @starts_at,
      ends_at: @ends_at,
      timezone: "UTC"
    )

    pickup = Appointments::Create.call(
      conversation: @conversation,
      role_key: "pickup",
      starts_at: @starts_at,
      ends_at: @ends_at.advance(hours: 2),
      timezone: "UTC"
    )

    assert visit.persisted?
    assert pickup.persisted?
    assert_equal 2, @conversation.appointments.current.count
  end

  test "appointment can have scheduled agent" do
    agent = agents(:alpha_alice_human)

    appointment = Appointments::Create.call(
      conversation: @conversation,
      role_key: "site_visit",
      starts_at: @starts_at,
      ends_at: @ends_at,
      timezone: "UTC",
      scheduled_agent: agent
    )

    assert_equal agent.id, appointment.scheduled_agent_id
  end
end
