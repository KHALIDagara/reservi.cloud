class ChannelThread < ApplicationRecord
  belongs_to :account
  belongs_to :channel
  belongs_to :conversation

  validates :external_thread_id, presence: true, uniqueness: { scope: :channel_id }
end
