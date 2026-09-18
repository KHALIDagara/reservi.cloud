module Accounts
  class CalendarExceptionsController < ApplicationController
    before_action :require_account_access!
    before_action :set_calendar_setting

    # POST   /a/:account_id/calendar_setting/calendar_exceptions
    def create
      Calendar::SaveException.call(
        calendar_setting: @setting,
        date:             params[:date],
        intervals:        parse_intervals(params[:intervals_value])
      )

      redirect_to edit_calendar_setting_path(current_account),
        notice: "Date exception saved."
    rescue Reservi::Errors::OperationError => e
      redirect_to edit_calendar_setting_path(current_account),
        alert: e.message
    end

    # PATCH/PUT /a/:account_id/calendar_setting/calendar_exceptions/:id
    def update
      exception = @setting.calendar_exceptions.find(params[:id])
      Calendar::SaveException.call(
        calendar_setting: @setting,
        date:             exception.date,
        intervals:        parse_intervals(params[:intervals_value])
      )

      redirect_to edit_calendar_setting_path(current_account),
        notice: "Exception updated."
    rescue Reservi::Errors::OperationError => e
      redirect_to edit_calendar_setting_path(current_account),
        alert: e.message
    end

    # DELETE /a/:account_id/calendar_setting/calendar_exceptions/:id
    def destroy
      exception = @setting.calendar_exceptions.find(params[:id])
      exception.destroy!

      redirect_to edit_calendar_setting_path(current_account),
        notice: "Exception removed."
    end

    private

    def parse_intervals(raw)
      return [] if raw.blank?
      raw.to_s.split(",").map do |pair|
        pair.strip.split("-").map(&:strip)
      end.reject { |p| p.size != 2 || p.any?(&:blank?) }
    end

    def set_calendar_setting
      @setting = current_membership.agent.calendar_setting
      unless @setting
        redirect_to edit_calendar_setting_path(current_account),
          alert: "Set up your calendar first." and return
      end
    end
  end
end