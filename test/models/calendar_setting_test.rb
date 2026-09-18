require "test_helper"

class CalendarSettingTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
  end

  def fresh_agent(name = "Test Agent #{rand(10000)}")
    user = User.create!(name: "Tmp", email_address: "tmp-#{rand(100000)}@example.com", password: "password123")
    membership = @account.memberships.create!(user: user, role: "operator", active: true)
    @account.agents.create!(membership: membership, name: name, kind: "human", active: true, operational_status: "active")
  end

  test "validates weekly_hours structure" do
    agent = fresh_agent
    setting = agent.build_calendar_setting(account: @account, timezone: "UTC")
    setting.weekly_hours = { "not_a_wday" => [["09:00", "17:00"]] }
    refute setting.valid?
    assert_includes setting.errors[:weekly_hours].first, "invalid weekday key"
  end

  test "validates interval format" do
    agent = fresh_agent
    setting = agent.build_calendar_setting(account: @account, timezone: "UTC")
    setting.weekly_hours = { "1" => [["25:00", "26:00"]] }
    refute setting.valid?
    assert_includes setting.errors[:weekly_hours].first, "invalid interval pair"
  end

  test "accepts valid weekly_hours" do
    agent = fresh_agent
    setting = agent.build_calendar_setting(account: @account, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]], "2" => [["09:00", "12:00"], ["13:00", "17:00"]] })
    assert setting.valid?
  end

  test "available_days returns days with non-zero intervals" do
    agent = fresh_agent
    setting = Calendar::SaveSettings.call(
      agent: agent, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]], "3" => [["10:00", "11:00"]] }
    )
    days = setting.available_days(from: Date.new(2026, 9, 14)) # Monday
    assert_includes days, Date.new(2026, 9, 14) # Monday
    assert_includes days, Date.new(2026, 9, 16) # Wednesday
    refute_includes days, Date.new(2026, 9, 15) # Tuesday — no hours configured
  end

  test "available_days returns empty when no hours configured" do
    agent = fresh_agent
    setting = Calendar::SaveSettings.call(agent: agent, timezone: "UTC", weekly_hours: {})
    assert_equal [], setting.available_days(from: Date.new(2026, 9, 1))
  end

  test "available_slots returns UTC timestamps" do
    agent = fresh_agent
    CalendarSetting.where(agent: agent).delete_all
    setting = CalendarSetting.create!(account: @account, agent: agent, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "11:00"]] })
    # Check intervals
    tz = setting.active_timezone
    assert_equal "UTC", tz.name
    intervals = setting.intervals_for_date(Date.new(2026, 9, 14))
    assert_equal 1, intervals.length
    assert_equal "09:00", intervals.first.first.strftime("%H:%M")
    assert_equal "11:00", intervals.first.last.strftime("%H:%M")
    # Slots: 09:00, 09:15, 09:30, 09:45, 10:00 (5 slots of 60 min each within 09:00-11:00)
    slots = setting.available_slots(date: Date.new(2026, 9, 14), duration_minutes: 60)
    assert_equal 5, slots.length
    assert_equal Time.utc(2026, 9, 14, 9, 0), slots.first
  end

  test "available_slots excludes already booked times" do
    agent = fresh_agent
    setting = Calendar::SaveSettings.call(
      agent: agent, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "11:00"]] }
    )
    conv = conversations(:alpha_active)
    conv.current_stage.update!(blocks: [{ "type" => "appointment", "role_key" => "test" }])
    Appointments::Book.call(
      conversation: conv,
      actor: agents(:alpha_alice_human),
      scheduled_agent: agent,
      role_key: "test",
      starts_at: Time.utc(2026, 9, 14, 9, 0),
      duration_minutes: 60,
      operation_key: "setup-blocked-slot-#{agent.id}"
    )

    slots = setting.available_slots(date: Date.new(2026, 9, 14), duration_minutes: 60)
    assert_equal 1, slots.length
    assert_equal Time.utc(2026, 9, 14, 10, 0), slots.first
  end

  test "available_slots honors duration constraints" do
    agent = fresh_agent
    setting = Calendar::SaveSettings.call(
      agent: agent, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "10:15"]] }
    )
    # 60 min slots: 09:00-10:00 and 09:15-10:15 both fit within 10:15 end
    slots_60 = setting.available_slots(date: Date.new(2026, 9, 14), duration_minutes: 60)
    assert_equal 2, slots_60.length

    # 15 min slots: 09:00, 09:15, 09:30, 09:45, 10:00 => 5
    slots_15 = setting.available_slots(date: Date.new(2026, 9, 14), duration_minutes: 15)
    assert_equal 5, slots_15.length
  end

  test "exceptions override weekly hours" do
    agent = fresh_agent
    setting = Calendar::SaveSettings.call(
      agent: agent, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]] }
    )
    Calendar::SaveException.call(
      calendar_setting: setting, date: Date.new(2026, 9, 14), intervals: []
    )
    slots = setting.available_slots(date: Date.new(2026, 9, 14), duration_minutes: 60)
    assert_equal 0, slots.length
  end

  test "available? returns false when busy" do
    agent = fresh_agent
    setting = Calendar::SaveSettings.call(
      agent: agent, timezone: "UTC",
      weekly_hours: { "1" => [["09:00", "17:00"]] }
    )
    # No bookings yet
    assert setting.available?(starts_at: Time.utc(2026, 9, 14, 10, 0), ends_at: Time.utc(2026, 9, 14, 11, 0))

    # Book the slot
    conv = conversations(:alpha_active)
    conv.current_stage.update!(blocks: [{ "type" => "appointment", "role_key" => "avail_test" }])
    Appointments::Book.call(
      conversation: conv,
      actor: agents(:alpha_alice_human),
      scheduled_agent: agent,
      role_key: "avail_test",
      starts_at: Time.utc(2026, 9, 14, 10, 0),
      duration_minutes: 60,
      operation_key: "avail-booking-#{agent.id}"
    )
    refute setting.available?(starts_at: Time.utc(2026, 9, 14, 10, 0), ends_at: Time.utc(2026, 9, 14, 11, 0))
  end
end