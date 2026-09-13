class Appointment < ApplicationRecord
  STATUSES = %w[pending confirmed cancelled completed].freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :scheduled_agent, class_name: "Agent", optional: true
  belongs_to :superseded_by, class_name: "Appointment", optional: true

  has_one :superseded, class_name: "Appointment", foreign_key: :superseded_by_id, dependent: :nullify

  validates :role_key, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :timezone, presence: true

  validate :ends_at_after_starts_at

  scope :active, -> { where(status: %w[pending confirmed]) }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :for_role, ->(key) { where(role_key: key) }
  scope :current, -> { where(superseded_by_id: nil) }
  scope :chronological, -> { order(starts_at: :asc) }

  def pending?    = status == "pending"
  def confirmed?  = status == "confirmed"
  def cancelled?  = status == "cancelled"
  def completed?  = status == "completed"

  private

  def ends_at_after_starts_at
    return unless starts_at && ends_at
    if ends_at <= starts_at
      errors.add(:ends_at, "must be after starts_at")
    end
  end
end