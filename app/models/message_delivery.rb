class MessageDelivery < ApplicationRecord
  DELIVERY_STATUSES = %w[pending sending sent failed delivered unknown].freeze

  belongs_to :account
  belongs_to :channel
  belongs_to :message

  validates :operation_key, presence: true, uniqueness: true
  validates :status, inclusion: { in: DELIVERY_STATUSES }

  def pending?
    status == "pending"
  end

  def sending?
    status == "sending"
  end

  def failed?
    status == "failed"
  end

  # Directed transition whitelist — prevents status regression.
  ALLOWED_TRANSITIONS = {
    "pending"  => %w[sending sent failed unknown],
    "sending"  => %w[sent failed delivered unknown],
    "sent"     => %w[delivered failed],
    "failed"   => %w[],
    "delivered" => %w[],
    "unknown"  => %w[]
  }.freeze

  def can_transition_to?(new_status)
    ALLOWED_TRANSITIONS.fetch(status, []).include?(new_status)
  end

  scope :pending, -> { where(status: "pending") }
  scope :sending, -> { where(status: "sending") }
  scope :failed, -> { where(status: "failed") }
end
