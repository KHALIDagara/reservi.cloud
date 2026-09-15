class AiRun < ApplicationRecord
  STATUSES       = %w[admitted evaluating completed failed cancelled].freeze
  ACTIVE_STATUSES = %w[admitted evaluating].freeze
  VALID_TRANSITIONS = {
    "admitted"   => %w[evaluating completed failed cancelled],
    "evaluating" => %w[completed failed cancelled],
    "completed"  => %w[],
    "failed"     => %w[],
    "cancelled"  => %w[]
  }.freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :agent
  belongs_to :agent_configuration

  validates :admission_token, presence: true,
    uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :trigger, presence: true

  scope :active,           -> { where(status: ACTIVE_STATUSES) }
  scope :for_conversation, ->(conversation) { where(conversation: conversation) }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def can_transition_to?(new_status)
    VALID_TRANSITIONS.fetch(status, []).include?(new_status.to_s)
  end

  # Transition helper — updates status and timestamp atomically.
  # Raises ActiveRecord::StaleObjectError or returns false when
  # the transition is invalid or a race is detected.
  def transition_to!(new_status)
    new_status = new_status.to_s
    unless can_transition_to?(new_status)
      raise ArgumentError,
        "Invalid transition from '#{status}' to '#{new_status}'"
    end

    updates = { status: new_status }

    case new_status
    when "evaluating"
      updates[:started_at] = Time.current
    when "completed"
      updates[:completed_at] = Time.current
    when "failed"
      updates[:failed_at] = Time.current
    end

    # Atomic compare-and-set prevents two workers racing to
    # complete the same run (old_status guard).
    rows = self.class
      .where(id: id, status: status)
      .update_all(updates.merge(updated_at: Time.current))

    if rows == 0
      raise ActiveRecord::StaleObjectError.new(self, "transition")
    end

    reload
    true
  end
end