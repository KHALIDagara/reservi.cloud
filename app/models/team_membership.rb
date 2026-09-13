class TeamMembership < ApplicationRecord
  belongs_to :account
  belongs_to :team
  belongs_to :agent

  validates :agent_id, uniqueness: { scope: :team_id }

  scope :active, -> { where(active: true) }
end