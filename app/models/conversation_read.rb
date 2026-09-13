class ConversationRead < ApplicationRecord
  belongs_to :conversation
  belongs_to :agent

  validates :agent_id, uniqueness: { scope: :conversation_id }
end