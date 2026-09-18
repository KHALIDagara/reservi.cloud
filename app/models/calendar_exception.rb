class CalendarException < ApplicationRecord
  belongs_to :calendar_setting

  validates :date, presence: true
  validates :date, uniqueness: { scope: :calendar_setting_id }
  validate :intervals_structure

  private

  def intervals_structure
    return if intervals.is_a?(Array)
    errors.add(:intervals, "must be an array of interval pairs")
    return
  end
  validate do
    return unless intervals.is_a?(Array)
    intervals.each do |pair|
      unless pair.is_a?(Array) && pair.size == 2 && pair.all? { |v| v.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/) }
        errors.add(:intervals, "invalid interval pair: #{pair.inspect}")
      end
    end
  end
end