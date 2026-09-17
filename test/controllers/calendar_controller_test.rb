require "test_helper"

class Accounts::CalendarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:alpha)
    sign_in_as(users(:alice))
  end

  test "shows calendar for any authenticated user" do
    get account_calendar_url(@account)
    assert_response :success
    assert_select "h1", text: "Calendar"
  end

  test "lists appointments in the viewable range" do
    conv = conversations(:alpha_active)
    conv.appointments.create!(
      account: @account,
      role_key: "consultation",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 1.hour,
      duration_minutes: 60,
      timezone: "UTC",
      status: "confirmed"
    )

    get account_calendar_url(@account)
    assert_response :success
    assert_select "a[href='#{account_conversation_path(@account, conv, panel: "open")}']"
  end

  test "cancelled appointments are excluded" do
    conv = conversations(:alpha_active)
    conv.appointments.create!(
      account: @account,
      role_key: "cancelled_meeting",
      starts_at: 2.days.from_now,
      ends_at: 2.days.from_now + 1.hour,
      duration_minutes: 60,
      timezone: "UTC",
      status: "cancelled"
    )

    get account_calendar_url(@account)
    assert_response :success
    refute_match(/cancelled_meeting/, response.body)
    refute_match(/cancelled/i, response.body.gsub("cancelled", ""))
  end
end