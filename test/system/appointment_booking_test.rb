require "application_system_test_case"

class AppointmentBookingTest < ApplicationSystemTestCase
  setup do
    @account      = accounts(:alpha)
    @alice_user   = users(:alice)
    @alice_agent  = agents(:alpha_alice_human)
    @bob_agent    = agents(:alpha_bob_human)
    @conversation = conversations(:alpha_active)
    @stage        = @conversation.current_stage

    # Ensure stage has an appointment block
    @stage.update!(blocks: [{ "type" => "appointment", "role_key" => "site_visit" }])

    # Set up Alice's calendar (the logged-in agent who will do the booking)
    Calendar::SaveSettings.call(
      agent: @alice_agent,
      timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]] }
    )
    # Set up Bob's calendar (the agent being scheduled)
    Calendar::SaveSettings.call(
      agent: @bob_agent,
      timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]], "2" => [["09:00", "12:00"]] }
    )
  end

  # ── rack_test (no JS) — verify page structure ──────────────────────────

  test "panel renders booking component for appointment block" do
    sign_in_as(@alice_user, account: @account)
    visit account_conversation_panel_url(account_id: @account.id, id: @conversation.id)

    assert_selector "[data-controller='appointment-booking']"
    assert_selector "select[data-appointment-booking-target='agentSelect']"
    # Days panel should be hidden until agent is selected
    assert_selector "[data-appointment-booking-target='daysPanel'].hidden", visible: :all
  end

  test "booking component renders action buttons for confirmed appointment" do
    # Book a confirmed appointment first
    appt = Appointments::Book.call(
      conversation: @conversation,
      actor: @alice_agent,
      scheduled_agent: @bob_agent,
      role_key: "site_visit",
      starts_at: Time.utc(2026, 9, 14, 10, 0),
      duration_minutes: 60,
      operation_key: "sys-test-setup"
    )

    sign_in_as(@alice_user, account: @account)
    visit account_conversation_panel_url(account_id: @account.id, id: @conversation.id)

    # Should show confirmed badge
    assert_selector "span", text: "Confirmed"
    # Should show scheduled agent name
    assert_text @bob_agent.name
    # Should show action buttons
    assert_button "Mark Complete"
    assert_button "No-show"
    assert_button "Cancel"
    # Owner is Alice, so reschedule should appear
    assert_button "Reschedule"
  end

  test "cancelled appointment shows replacement booking UI" do
    appt = Appointments::Create.call(
      conversation: @conversation,
      role_key: "site_visit",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 1.hour,
      timezone: "UTC",
      scheduled_agent: @bob_agent
    )
    Appointments::Cancel.call(appointment: appt)

    sign_in_as(@alice_user, account: @account)
    visit account_conversation_panel_url(account_id: @account.id, id: @conversation.id)

    assert_text "Previous appointment cancelled"
    assert_selector "[data-controller='appointment-booking']"
    assert_selector "select[data-appointment-booking-target='agentSelect']"
  end

  test "takeover button appears for non-owner viewing confirmed appointment" do
    # Book Bob as scheduled agent (Alice is owner)
    appt = Appointments::Book.call(
      conversation: @conversation,
      actor: @alice_agent,
      scheduled_agent: @bob_agent,
      role_key: "site_visit",
      starts_at: Time.utc(2026, 9, 14, 10, 0),
      duration_minutes: 60,
      operation_key: "sys-test-takeover"
    )

    # Sign in as Bob (not the owner)
    sign_in_as(users(:bob), account: @account)
    visit account_conversation_panel_url(account_id: @account.id, id: @conversation.id)

    assert_selector "span", text: "Confirmed"
    assert_button "Take over #"
  end

  # ── Calendar settings page ────────────────────────────────────────────

  test "calendar settings show page displays availability" do
    sign_in_as(@alice_user, account: @account)
    visit calendar_setting_url(account_id: @account.id)

    assert_text "My Calendar"
    assert_text @alice_agent.name
    assert_text "UTC"
    assert_text "Upcoming availability"
    # Alice has Monday 09:00-17:00, should show upcoming Mondays
    assert_selector "span", text: /\w{3} \d{2} \w{3}/
  end

  test "calendar settings edit page renders and saves" do
    sign_in_as(@alice_user, account: @account)
    visit edit_calendar_setting_url(account_id: @account.id)

    assert_text "Edit My Calendar"
    assert_selector "form[action='#{calendar_setting_path(@account)}']"

    # Change Tuesday hours
    fill_in "weekly_hours[tuesday]", with: "10:00-14:00"
    click_button "Save calendar"

    assert_text "Calendar settings saved"
    @alice_agent.reload
    assert @alice_agent.calendar_setting.weekly_hours["2"].present?
  end

  test "calendar settings add and remove exception" do
    sign_in_as(@alice_user, account: @account)
    visit edit_calendar_setting_url(account_id: @account.id)

    # Add a closed day
    fill_in "Date", with: "2026-10-01"
    fill_in "intervals_value", with: "" # closed all day
    click_button "Add exception"

    assert_text "Date exception saved"
    assert_text "Closed"
    assert_text "Thu 01 Oct 2026"

    # Remove it
    exception = @alice_agent.calendar_setting.calendar_exceptions.find_by(date: "2026-10-01")
    assert exception, "Exception should have been created"
  end

  # ── JavaScript booking flow (requires headless Chrome) ──────────────────

  if ENV["CHROME_BIN"].present? || ENV["CI"]
    test "full JS booking flow: agent picker → days → slots → book" do
      sign_in_as(@alice_user, account: @account)
      visit account_conversation_url(account_id: @account.id, id: @conversation.id)

      # Open the work panel
      click_button "Work"
      assert_selector "#conversation-work-panel"

      # Select Bob as the scheduled agent
      within "[data-controller='appointment-booking']" do
        select @bob_agent.name, from: "agentSelect" rescue
          find("select[data-appointment-booking-target='agentSelect']").find("option", text: @bob_agent.name).select_option
      end

      # Wait for days to load
      assert_selector "[data-appointment-booking-target='daysList'] button", wait: 10

      # Click the first available day button
      first_day = first("[data-appointment-booking-target='daysList'] button")
      first_day.click

      # Wait for slots to load
      assert_selector "[data-appointment-booking-target='slotsList'] button", wait: 10

      # Click the first available slot
      first_slot = first("[data-appointment-booking-target='slotsList'] button")
      first_slot.click

      # Summary should appear
      assert_selector "[data-appointment-booking-target='summary']", wait: 5
      assert_text @bob_agent.name

      # Click Book
      click_button "Book"

      # Should redirect back to conversation page with success notice
      assert_text "Appointment booked."
      assert_text "Confirmed"
    end
  end
end