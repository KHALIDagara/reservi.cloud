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
  has_many :field_definitions
  has_many :catalogs
  has_many :items
  has_many :item_selections
  has_many :appointments
  has_many :channels, dependent: :destroy
  has_many :channel_threads, dependent: :destroy
  has_many :message_deliveries, dependent: :destroy
  has_many :agent_configurations
  has_many :ai_runs
  has_many :knowledge_sources
  has_many :knowledge_revisions, through: :knowledge_sources, source: :revisions

  validates :name, presence: true
  validates :locale, presence: true
  validates :timezone, presence: true

  def active?
    active
  end
end