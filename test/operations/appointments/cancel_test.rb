require "test_helper"

class Appointments::CancelTest < ActiveSupport::TestCase
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

  test "cancels a confirmed appointment" do
    result = Appointments::Cancel.call(appointment: @appointment, reason: "Customer cancelled")
    assert_equal "cancelled", result.status
    assert_equal "Customer cancelled", result.cancellation_reason
    assert result.cancelled_at.present?
  end

  test "cannot cancel already cancelled appointment" do
    Appointments::Cancel.call(appointment: @appointment)
    assert_raises(Reservi::Errors::OperationError, match: /already cancelled/) do
      Appointments::Cancel.call(appointment: @appointment)
    end
  end

  test "cannot cancel completed appointment" do
    @appointment.update!(status: "completed")
    assert_raises(Reservi::Errors::OperationError, match: /already completed/) do
      Appointments::Cancel.call(appointment: @appointment)
    end
  end

  test "cancelling releases the time slot — new appointment can be created" do
    Appointments::Cancel.call(appointment: @appointment)

    # Use Appointments::Create which handles superseding
    replacement = Appointments::Create.call(
      conversation: @conversation,
      role_key: "site_visit",
      starts_at: @starts_at,
      ends_at: @ends_at,
      timezone: "UTC",
      scheduled_agent: @alice
    )

    # Now it can be confirmed because the old one was cancelled (no longer "confirmed" + superseded)
    result = Appointments::Confirm.call(appointment: replacement)
    assert_equal "confirmed", result.status
  end
end
