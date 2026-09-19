class Message < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze
  DELIVERY_STATUSES = %w[local received sent delivered failed unknown].freeze

  belongs_to :conversation, touch: true
  belongs_to :agent, optional: true
  has_many :attachments, dependent: :destroy

  # Allow messages that have attachments but no text content
  validates :author_name, presence: true
  validates :content, presence: true, unless: :has_attachments?
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :delivery_status, inclusion: { in: DELIVERY_STATUSES }

  scope :chronological, -> { order(created_at: :asc, id: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc, id: :desc) }
  scope :inbound, -> { where(direction: "inbound") }
  scope :outbound, -> { where(direction: "outbound") }

  def has_attachments?
    attachments.loaded? ? attachments.any? : attachments.exists?
  end
end
