class Channel < ApplicationRecord
  PROVIDER_TYPES = %w[dev whatsapp instagram].freeze

  belongs_to :account
  belongs_to :default_agent, class_name: "Agent", optional: true
  belongs_to :default_team, class_name: "Team", optional: true
  encrypts :credentials
  serialize :credentials, coder: JSON
  has_many :channel_threads, dependent: :destroy
  has_many :conversations, through: :channel_threads
  # Direct access to all deliveries through this channel
  has_many :deliveries, class_name: "MessageDelivery", foreign_key: :channel_id, dependent: :destroy
  has_many :webhook_receipts, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :provider_type, presence: true, inclusion: { in: PROVIDER_TYPES }
  validates :inbound_token, presence: true, uniqueness: true
  validates :provider_external_id, uniqueness: { scope: :provider_type }, allow_nil: true
  validate :at_most_one_default_assignment

  scope :active, -> { where(active: true) }

  def credential(key)
    (credentials || {})[key.to_s] || provider_config[key.to_s]
  end

  private

  def at_most_one_default_assignment
    if default_agent_id.present? && default_team_id.present?
      errors.add(:base, "A channel may specify either a default agent or a default team, not both.")
    end
  end
end
