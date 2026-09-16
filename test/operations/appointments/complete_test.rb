require "test_helper"

class Appointments::CompleteTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @conversation = conversations(:alpha_active)
    @alice = agents(:alpha_alice_human)

    @starts_at = Time.zone.parse("2026-09-15 14:00:00 UTC")
    @ends_at = Time.zone.parse("2026-09-15 15:00:00 UTC")

    @appointment = @conversation.appointments.create!(
      account: @account,
      role_key: "site_visit",
      starts_at: @starts_at,
      ends_at: @ends_at,
      duration_minutes: 60,
      timezone: "UTC",
      scheduled_agent: @alice,
      status: "confirmed"
    )
  end

  test "completes a confirmed appointment" do
    result = Appointments::Complete.call(appointment: @appointment)
    assert_equal "completed", result.status
    assert result.completed_at.present?
  end

  test "completes a pending appointment" do
    @appointment.update!(status: "pending")
    result = Appointments::Complete.call(appointment: @appointment)
    assert_equal "completed", result.status
  end

  test "cannot complete already completed" do
    Appointments::Complete.call(appointment: @appointment)
    assert_raises(Reservi::Errors::OperationError, match: /already completed/) do
      Appointments::Complete.call(appointment: @appointment)
    end
  end

  test "cannot complete a cancelled appointment" do
    @appointment.update!(status: "cancelled")
    assert_raises(Reservi::Errors::OperationError, match: /cancelled/) do
      Appointments::Complete.call(appointment: @appointment)
    end
  end

  test "does not change flow state" do
    Appointments::Complete.call(appointment: @appointment)
    @conversation.reload
    assert @conversation.active?  # flow state unchanged
  end
end
