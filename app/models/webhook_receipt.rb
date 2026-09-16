class WebhookReceipt < ApplicationRecord
  belongs_to :account
  belongs_to :channel

  validates :provider_event_id, presence: true, uniqueness: { scope: :channel_id }
  validates :event_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_channel, ->(channel) { where(channel: channel) }

  # Deduplicating factory: returns the receipt, and whether it was a new record.
  # Callers use `previously_new_record?` to decide if processing should proceed.
  def self.process!(channel:, provider_event_id:, event_type:, payload: {})
    receipt = find_or_create_by!(
      channel: channel,
      provider_event_id: provider_event_id
    ) do |r|
      r.account = channel.account
      r.event_type = event_type
      r.payload = payload
    end
    receipt
  end
end