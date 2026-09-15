class CreateKnowledge < ActiveRecord::Migration[8.1]
  def up
    # ── knowledge_sources ──────────────────────────────────
    create_table :knowledge_sources do |t|
      t.references :account,         null: false, foreign_key: true
      t.string     :title,           null: false
      t.string     :kind,            null: false
      t.boolean    :shared,          null: false, default: true
      t.bigint     :current_revision_id  # FK added after knowledge_revisions exists
      t.boolean    :archived,        null: false, default: false
      t.timestamps
    end

    add_check_constraint :knowledge_sources,
      "kind IN ('qa', 'document', 'scenario')",
      name: "knowledge_sources_kind_check"

    add_index :knowledge_sources, [:account_id, :title],
      unique: true,
      where: "archived = false",
      name: "idx_knowledge_sources_account_title_active"

    # ── knowledge_revisions ────────────────────────────────
    create_table :knowledge_revisions do |t|
      t.references :knowledge_source, null: false, foreign_key: true
      t.integer    :version_number,   null: false
      t.string     :status,           null: false, default: "draft"
      t.jsonb      :content_json,     null: false, default: {}
      t.text       :raw_text
      t.datetime   :published_at, precision: 6
      t.timestamps
    end

    add_check_constraint :knowledge_revisions,
      "status IN ('draft', 'published')",
      name: "knowledge_revisions_status_check"

    add_index :knowledge_revisions, [:knowledge_source_id, :version_number],
      unique: true,
      name: "idx_knowledge_revisions_source_version"

    # Add FK from knowledge_sources.current_revision_id to knowledge_revisions
    add_foreign_key :knowledge_sources, :knowledge_revisions,
      column: :current_revision_id
    add_index :knowledge_sources, :current_revision_id,
      name: "idx_knowledge_sources_current_revision"

    # ── agent_knowledge_grants ─────────────────────────────
    create_table :agent_knowledge_grants do |t|
      t.references :account,            null: false, foreign_key: true
      t.references :agent,              null: false, foreign_key: true
      t.references :knowledge_source,   null: false, foreign_key: true
      t.boolean    :active,             null: false, default: true
      t.timestamps
    end

    add_index :agent_knowledge_grants, [:agent_id, :knowledge_source_id],
      unique: true,
      name: "idx_agent_knowledge_grants_agent_source"
  end

  def down
    remove_foreign_key :knowledge_sources, :knowledge_revisions,
      column: :current_revision_id
    drop_table :agent_knowledge_grants
    drop_table :knowledge_revisions
    drop_table :knowledge_sources
  end
end