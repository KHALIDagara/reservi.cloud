module Accounts
  # Personal calendar settings for the logged-in agent.
  #
  # Each human agent manages their own weekly hours and exceptions.
  # The controller always operates on the current_agent's calendar_setting
  # so there is no privilege escalation risk.
  class CalendarSettingsController < ApplicationController
    before_action :require_account_access!

    # GET  /a/:account_id/calendar_setting
    def show
      @setting = current_agent.calendar_setting
      unless @setting
        redirect_to edit_calendar_setting_path(current_account),
          alert: "Set up your calendar first." and return
      end
    end

    # GET  /a/:account_id/calendar_setting/edit
    def edit
      @setting = current_agent.calendar_setting || current_agent.build_calendar_setting(
        account: current_account
      )
      @timezones = ActiveSupport::TimeZone.all.sort_by(&:utc_offset)
    end

    # PATCH/PUT /a/:account_id/calendar_setting
    def update
      Calendar::SaveSettings.call(
        agent:        current_agent,
        timezone:     params[:timezone],
        weekly_hours: parse_weekly_hours(params[:weekly_hours])
      )

      redirect_to calendar_setting_path(current_account),
        notice: "Calendar settings saved."
    rescue Reservi::Errors::OperationError => e
      @setting = current_agent.calendar_setting || current_agent.build_calendar_setting(
        account: current_account,
        timezone: params[:timezone]
      )
      @timezones = ActiveSupport::TimeZone.all.sort_by(&:utc_offset)
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    private

    def current_agent
      current_membership.agent
    end

    # "weekly_hours" comes in as { "monday" => ["09:00-17:00", ...], ... }
    # Convert to { "1" => [["09:00","17:00"], ...] }
    def parse_weekly_hours(raw)
      return {} if raw.blank?

      day_map = {
        "monday" => "1", "tuesday" => "2", "wednesday" => "3",
        "thursday" => "4", "friday" => "5", "saturday" => "6", "sunday" => "0"
      }

      result = {}
      raw.each do |day_name, intervals|
        wday = day_map[day_name.downcase]
        next unless wday

        pairs = Array(intervals).map do |i|
          i.to_s.strip.split("-").map(&:strip)
        end
        result[wday] = pairs.reject { |p| p.size != 2 || p.any?(&:blank?) }
      end

      # Ensure all days at least have empty arrays
      %w[0 1 2 3 4 5 6].each { |d| result[d] ||= [] }
      result
    end
  end
end