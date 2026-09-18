class CalendarSetting < ApplicationRecord
  belongs_to :account
  belongs_to :agent

  has_many :calendar_exceptions, dependent: :destroy

  validates :timezone, presence: true
  validates :agent_id, uniqueness: { scope: :account_id }
  validate :agent_must_be_active_human
  validate :weekly_hours_structure

  # Returns the timezone as an ActiveSupport::TimeZone or the account's
  # timezone as a fallback.
  def active_timezone
    ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone[account.timezone] ||
      ActiveSupport::TimeZone["UTC"]
  end

  # Compute the next n (max 62) upcoming days that have at least one
  # non-zero-duration interval, starting from the configured timezone's
  # today.  A nil weekly_hours means zero available time.
  def available_days(from: active_timezone.today, up_to_days: 62)
    return [] if weekly_hours.blank?

    limit = [up_to_days, 62].min
    days = (0..limit).map { |offset| from + offset.days }
    days.select { |date| intervals_for_date(date).any? }
  end

  # Ordered UTC slot timestamps for a given date, using the configured
  # timezone.  Returns an array of Time objects (duration minutes long)
  # stepping at 15 minute intervals.  Existing appointments (excluding the
  # optional excluding_appointment) are removed.  Duration must be 15..480
  # minutes and a multiple of 15.
  def available_slots(date:, duration_minutes:, excluding_appointment: nil)
    tz = active_timezone
    intervals = intervals_for_date(date)

    slots = []
    intervals.each do |interval|
      start_time = interval.first
      while start_time + duration_minutes.minutes <= interval.last
        utc = tz.local_to_utc(start_time)
        utc_end = utc + duration_minutes.minutes

        # Exclude overlapping confirmed bookings for this agent
        unless agent_conflicts?(utc, utc_end, excluding_appointment: excluding_appointment)
          slots << utc
        end
        start_time += 15.minutes
      end
    end
    slots
  end

  # Check whether a specific time range is available for this agent.
  def available?(starts_at:, ends_at:, exclude_appointment: nil)
    tz = active_timezone
    local_start = starts_at.in_time_zone(tz)
    return false unless local_start
    intervals = intervals_for_date(local_start.to_date)
    return false if intervals.empty?

    covers = intervals.any? do |interval|
      interval.first <= local_start && interval.last >= local_start + ((ends_at - starts_at) / 60).minutes
    end
    return false unless covers

    !agent_conflicts?(starts_at, ends_at, excluding_appointment: exclude_appointment)
  end

  # All intervals for a date: weekly hours merged with date-specific exception.
  # Returns an array of [local_time, local_time] pairs.
  def intervals_for_date(date)
    exception = calendar_exceptions.find_by(date: date)
    if exception
      parse_interval_pairs(exception.intervals, date)
    else
      wday = date.wday.to_s
      parse_interval_pairs(weekly_hours[wday] || [], date)
    end
  end

  private

  def agent_must_be_active_human
    return unless agent
    unless agent.active? && agent.kind == "human"
      errors.add(:agent, "must be an active human agent")
    end
  end

  WEEKLY_HOURS_SCHEMA = {
    "0" => "an array of ['HH:MM', 'HH:MM'] pairs",
    "1" => "an array of ['HH:MM', 'HH:MM'] pairs",
    "2" => "an array of ['HH:MM', 'HH:MM'] pairs",
    "3" => "an array of ['HH:MM', 'HH:MM'] pairs",
    "4" => "an array of ['HH:MM', 'HH:MM'] pairs",
    "5" => "an array of ['HH:MM', 'HH:MM'] pairs",
    "6" => "an array of ['HH:MM', 'HH:MM'] pairs"
  }.freeze

  VALID_WDAYS = %w[0 1 2 3 4 5 6].freeze

  def weekly_hours_structure
    return if weekly_hours.blank?
    unless weekly_hours.is_a?(Hash)
      errors.add(:weekly_hours, "must be a Hash mapping weekday strings to interval arrays")
      return
    end
    weekly_hours.each do |wday, intervals|
      unless VALID_WDAYS.include?(wday.to_s)
        errors.add(:weekly_hours, "invalid weekday key '#{wday}'")
      end
      unless intervals.is_a?(Array)
        errors.add(:weekly_hours, "value for '#{wday}' must be an array")
      end
      intervals.each do |pair|
        unless pair.is_a?(Array) && pair.size == 2 && pair.all? { |v| v.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/) }
          errors.add(:weekly_hours, "invalid interval pair for '#{wday}': #{pair.inspect}")
        end
      end
    end
  end

  def parse_interval_pairs(pairs, date)
    return [] if pairs.nil? || (pairs.is_a?(Array) && pairs.empty?)
    tz = active_timezone
    pairs.map do |pair|
      start_str, end_str = pair
      local_start = Time.strptime(start_str, "%H:%M").in_time_zone(tz)
        .change(year: date.year, month: date.month, day: date.day)
      local_end   = Time.strptime(end_str,   "%H:%M").in_time_zone(tz)
        .change(year: date.year, month: date.month, day: date.day)
      [local_start, local_end]
    end.sort_by(&:first)
  end

  # Checks against the exclusion constraint: any confirmed appointment
  # for this agent that overlaps [starts_at, ends_at).
  def agent_conflicts?(starts_at, ends_at, excluding_appointment: nil)
    scope = agent.appointments
      .current
      .confirmed
      .where("tsrange(starts_at, ends_at, '[)'::text) && tsrange(?, ?, '[)'::text)", starts_at, ends_at)
    scope = scope.where.not(id: excluding_appointment.id) if excluding_appointment
    scope.exists?
  end
end