class AppointmentEvent < ApplicationRecord
  ACTIONS = %w[created confirmed cancelled completed no_show rescheduled reassigned status_changed].freeze

  belongs_to :appointment
  belongs_to :actor, class_name: "Agent", optional: true

  validates :action, inclusion: { in: ACTIONS }

  scope :chronological, -> { order(created_at: :asc) }
end