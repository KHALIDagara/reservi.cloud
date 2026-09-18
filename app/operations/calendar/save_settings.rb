module Calendar
  # Saves or updates an Agent's calendar settings (weekly hours, timezone, exceptions).
  #
  # Usage:
  #   Calendar::SaveSettings.call(
  #     agent: agent,
  #     timezone: "Africa/Casablanca",
  #     weekly_hours: { "1" => [["09:00","17:00"]], ... }
  #   )
  #
  # Exceptions are managed separately through Calendar::SaveException.
  class SaveSettings
    def self.call(agent:, timezone:, weekly_hours:)
      new(agent:, timezone:, weekly_hours:).call
    end

    def initialize(agent:, timezone:, weekly_hours:)
      @agent        = agent
      @timezone     = timezone
      @weekly_hours = weekly_hours
    end

    def call
      raise Reservi::Errors::OperationError, "Agent must be schedulable" unless @agent.schedulable?
      raise Reservi::Errors::OperationError, "Invalid timezone" unless ActiveSupport::TimeZone[@timezone]

      setting = @agent.calendar_setting || @agent.build_calendar_setting
      setting.account = @agent.account
      setting.timezone = @timezone
      setting.weekly_hours = @weekly_hours || {}
      setting.save!
      setting
    end
  end
end