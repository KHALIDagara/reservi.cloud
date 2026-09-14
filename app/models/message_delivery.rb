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

  scope :pending, -> { where(status: "pending") }
  scope :sending, -> { where(status: "sending") }
  scope :failed, -> { where(status: "failed") }
end