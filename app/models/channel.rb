class Channel < ApplicationRecord
  belongs_to :account
  has_many :channel_threads, dependent: :destroy
  has_many :message_deliveries, through: :channel_threads, source: :conversation
  # Direct access to all deliveries through this channel
  has_many :deliveries, class_name: "MessageDelivery", foreign_key: :channel_id, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :provider_type, presence: true
  validates :inbound_token, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end