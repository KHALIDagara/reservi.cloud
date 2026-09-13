class Account < ApplicationRecord
  has_many :memberships
  has_many :users, through: :memberships
  has_many :agents
  has_many :teams
  has_many :team_memberships
  has_many :account_invitations
  has_many :customers
  has_many :flows
  has_many :conversations

  validates :name, presence: true
  validates :locale, presence: true
  validates :timezone, presence: true

  def active?
    active
  end
end