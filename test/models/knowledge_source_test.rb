require "test_helper"

class KnowledgeSourceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
  end

  test "creates with valid attributes" do
    source = KnowledgeSource.new(
      account: @account,
      title:   "Shipping Policy",
      kind:    "document"
    )
    assert source.valid?
  end

  test "validates title uniqueness per account" do
    KnowledgeSource.create!(account: @account, title: "FAQ", kind: "qa")

    duplicate = KnowledgeSource.new(account: @account, title: "FAQ", kind: "qa")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:title].join, "taken"
  end

  test "allows same title in different accounts" do
    KnowledgeSource.create!(account: @account, title: "FAQ", kind: "qa")

    other = KnowledgeSource.new(account: accounts(:beta), title: "FAQ", kind: "qa")
    assert other.valid?
  end

  test "validates kind inclusion" do
    source = KnowledgeSource.new(account: @account, title: "Test", kind: "bogus")
    assert_not source.valid?
    assert_includes source.errors[:kind].join, "not included"
  end

  test "scope :active excludes archived" do
    active   = KnowledgeSource.create!(account: @account, title: "Active Doc",   kind: "document")
    archived = KnowledgeSource.create!(account: @account, title: "Archived Doc", kind: "document")
    archived.update!(archived: true)

    active_sources = KnowledgeSource.active
    assert_includes     active_sources, active
    assert_not_includes active_sources, archived
  end

  test "scope :shared returns only shared" do
    shared   = KnowledgeSource.create!(account: @account, title: "Shared QA",  kind: "qa",       shared: true)
    private  = KnowledgeSource.create!(account: @account, title: "Private QA", kind: "qa",       shared: false)

    shared_sources = KnowledgeSource.shared
    assert_includes     shared_sources, shared
    assert_not_includes shared_sources, private
  end

  test "has_many revisions works" do
    source = KnowledgeSource.create!(account: @account, title: "Revisions Doc", kind: "document")
    rev1 = source.revisions.create!(version_number: 1, status: "draft")
    rev2 = source.revisions.create!(version_number: 2, status: "published")

    assert_equal 2, source.revisions.count
    assert_includes source.revisions, rev1
    assert_includes source.revisions, rev2
  end

  test "has_many grants works" do
    source = KnowledgeSource.create!(account: @account, title: "Grants Doc", kind: "scenario")
    agent  = agents(:alpha_alice_human)
    grant  = AgentKnowledgeGrant.create!(account: @account, agent: agent, knowledge_source: source)

    assert_includes source.grants, grant
    assert_includes source.agents, agent
  end

  test "archived? returns correct value" do
    source = KnowledgeSource.create!(account: @account, title: "Archive Test", kind: "qa")
    assert_not source.archived?

    source.update!(archived: true)
    assert source.archived?
  end

  test "belongs to current_revision" do
    source = KnowledgeSource.create!(account: @account, title: "Current Rev Test", kind: "qa")
    rev    = source.revisions.create!(version_number: 1, status: "published")

    source.update!(current_revision: rev)
    assert_equal rev, source.current_revision
  end
end