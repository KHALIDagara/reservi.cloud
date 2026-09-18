class Channel < ApplicationRecord
  PROVIDER_TYPES = %w[dev whatsapp instagram].freeze

  belongs_to :account
  encrypts :credentials
  serialize :credentials, coder: JSON
  has_many :channel_threads, dependent: :destroy
  has_many :message_deliveries, through: :channel_threads, source: :conversation
  # Direct access to all deliveries through this channel
  has_many :deliveries, class_name: "MessageDelivery", foreign_key: :channel_id, dependent: :destroy
  has_many :webhook_receipts, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :provider_type, presence: true, inclusion: { in: PROVIDER_TYPES }
  validates :inbound_token, presence: true, uniqueness: true
  validates :provider_external_id, uniqueness: { scope: :provider_type }, allow_nil: true

  scope :active, -> { where(active: true) }

  def credential(key)
    (credentials || {})[key.to_s] || provider_config[key.to_s]
  end

  def deactivate!
    update!(active: false)
  end
end
