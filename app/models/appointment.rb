class Appointment < ApplicationRecord
  STATUSES = %w[pending confirmed cancelled completed no_show].freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :scheduled_agent, class_name: "Agent", optional: true
  belongs_to :superseded_by, class_name: "Appointment", optional: true
  belongs_to :created_by, class_name: "Agent", optional: true

  has_one :superseded, class_name: "Appointment", foreign_key: :superseded_by_id, dependent: :nullify
  has_many :appointment_events, dependent: :destroy

  validates :role_key, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validates :timezone, presence: true

  validate :ends_at_after_starts_at

  scope :active,       -> { where(status: %w[pending confirmed]) }
  scope :confirmed,    -> { where(status: "confirmed") }
  scope :for_role,     ->(key) { where(role_key: key) }
  scope :current,      -> { where(superseded_by_id: nil) }
  scope :chronological,-> { order(starts_at: :asc) }
  scope :for_agent,    ->(agent_id) { where(scheduled_agent_id: agent_id) }

  def pending?    = status == "pending"
  def confirmed?  = status == "confirmed"
  def cancelled?  = status == "cancelled"
  def completed?  = status == "completed"
  def no_show?    = status == "no_show"

  def terminal?
    cancelled? || completed? || no_show?
  end

  def editable?
    pending? || confirmed?
  end

  def record_event!(action:, actor:, before_state: {}, after_state: {})
    appointment_events.create!(
      action: action,
      actor: actor,
      before_state: before_state,
      after_state: after_state
    )
  end

  private

  def ends_at_after_starts_at
    return unless starts_at && ends_at
    if ends_at <= starts_at
      errors.add(:ends_at, "must be after starts_at")
    end
  end
end