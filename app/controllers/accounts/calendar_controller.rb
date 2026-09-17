module Accounts
  class CalendarController < ApplicationController
    before_action :require_account_access!

    def index
      @today = current_account_time.to_date
      @start_date = parse_date(:start, @today.beginning_of_month)
      @end_date   = parse_date(:end, (@today + 2.months).end_of_month)

      range = @start_date.beginning_of_day..@end_date.end_of_day
      @appointments = current_account.appointments
        .includes(conversation: [ :customer, :owner ])
        .where(starts_at: range)
        .where.not(status: [ "cancelled" ])
        .order(starts_at: :asc)

      @grouped = @appointments.group_by { |a| a.starts_at.to_date }
      @months  = build_months
    end

    private

    def current_account_time
      Time.current
    end

    def parse_date(param, fallback)
      date = params[param]&.then { |v| Date.parse(v) rescue nil }
      date || fallback.to_date
    end

    def build_months
      months = []
      cursor = @start_date.beginning_of_month
      while cursor <= @end_date
        months << build_month_grid(cursor)
        cursor = cursor.next_month
      end
      months
    end

    def build_month_grid(first_of_month)
      last_of_month  = first_of_month.end_of_month
      start_pad = first_of_month.wday.zero? ? 6 : first_of_month.wday - 1 # Monday = 0
      days = []

      # Pad before the 1st
      start_pad.times do |n|
        days << { date: first_of_month - (start_pad - n).days, in_month: false }
      end

      (first_of_month..last_of_month).each do |d|
        days << { date: d, in_month: true }
      end

      # Pad to complete the last week
      remaining = 7 - (days.size % 7)
      remaining = 0 if remaining == 7
      remaining.times do |n|
        days << { date: last_of_month + (n + 1).days, in_month: false }
      end

      weeks = days.each_slice(7).to_a

      {
        label: first_of_month.strftime("%B %Y"),
        weeks: weeks
      }
    end
  end
end
