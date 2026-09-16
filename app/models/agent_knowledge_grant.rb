class AgentKnowledgeGrant < ApplicationRecord
  belongs_to :account
  belongs_to :agent
  belongs_to :knowledge_source

  validates :agent_id, uniqueness: { scope: :knowledge_source_id }

  scope :active, -> { where(active: true) }
end
