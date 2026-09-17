class Conversation < ApplicationRecord
  PROCESS_STATUSES = %w[active completed cancelled].freeze

  belongs_to :account
  belongs_to :customer
  belongs_to :flow_version, optional: true
  belongs_to :current_stage, class_name: "Stage", optional: true
  belongs_to :owner, class_name: "Agent", optional: true
  belongs_to :team, optional: true

  has_many :messages, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :conversation_reads, dependent: :destroy
  has_many :stage_transitions, dependent: :destroy
  has_many :item_selections, dependent: :destroy
  has_many :rule_executions, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :channel_threads, dependent: :destroy
  has_many :ai_runs, dependent: :destroy

  validates :process_status, inclusion: { in: PROCESS_STATUSES }
  validates :stage_entry_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(process_status: "active") }
  scope :inbox, -> { active.order(last_activity_at: :desc, id: :desc) }
  scope :needing_attention, -> { inbox.where(attention: true) }
  scope :owned_by, ->(agent_id) { where(owner_id: agent_id) }
  scope :unowned, -> { where(owner_id: nil) }
  scope :for_team, ->(team_id) { where(team_id: team_id) }

  # ── Revision counter ────────────────────────────────────────
  # Every meaningful state mutation bumps revision so AiRun can
  # detect concurrent changes.  Timestamp-only updates (e.g.
  # last_activity_at touch) skip the increment.
  attr_accessor :skip_revision_increment

  before_update :increment_revision

  def active?
    process_status == "active"
  end

  def cancelled?
    process_status == "cancelled"
  end

  def unowned?
    owner_id.nil?
  end

  private

  def increment_revision
    if skip_revision_increment
      self.skip_revision_increment = nil
      return
    end
    self.revision += 1
  end
end
