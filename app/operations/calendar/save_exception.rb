module Calendar
  # Creates or updates a single-day exception for an Agent's calendar.
  #
  # Usage:
  #   Calendar::SaveException.call(
  #     calendar_setting: setting,
  #     date: "2026-09-20",
  #     intervals: []  # closed all day
  #   )
  class SaveException
    def self.call(calendar_setting:, date:, intervals: [])
      new(calendar_setting:, date:, intervals:).call
    end

    def initialize(calendar_setting:, date:, intervals: [])
      @calendar_setting = calendar_setting
      @date      = date.is_a?(Date) ? date : Date.parse(date.to_s)
      @intervals = Array(intervals)
    end

    def call
      exception = @calendar_setting.calendar_exceptions.find_or_initialize_by(date: @date)
      exception.intervals = @intervals
      exception.save!
      exception
    end
  end
end