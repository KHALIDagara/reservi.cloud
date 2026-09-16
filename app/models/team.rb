class Team < ApplicationRecord
  belongs_to :account

  has_many :team_memberships
  has_many :agents, through: :team_memberships

  validates :name, presence: true, uniqueness: { scope: :account_id }

  scope :active, -> { where(active: true) }
end
