require "test_helper"

class KnowledgeRevisionTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @source  = KnowledgeSource.create!(account: @account, title: "Revision Test Source", kind: "document")
  end

  test "creates with valid attributes" do
    revision = KnowledgeRevision.new(
      knowledge_source: @source,
      version_number:   1,
      status:           "draft"
    )
    assert revision.valid?
  end

  test "version_number uniqueness per source" do
    @source.revisions.create!(version_number: 1, status: "draft")

    duplicate = KnowledgeRevision.new(
      knowledge_source: @source,
      version_number:   1,
      status:           "published"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:version_number].join, "taken"
  end

  test "allows same version_number for different sources" do
    @source.revisions.create!(version_number: 1, status: "draft")

    source2  = KnowledgeSource.create!(account: @account, title: "Other Source", kind: "qa")
    revision = KnowledgeRevision.new(
      knowledge_source: source2,
      version_number:   1,
      status:           "published"
    )
    assert revision.valid?
  end

  test "scope :published works" do
    draft_rev     = @source.revisions.create!(version_number: 1, status: "draft")
    published_rev = @source.revisions.create!(version_number: 2, status: "published")

    published = KnowledgeRevision.published
    assert_includes     published, published_rev
    assert_not_includes published, draft_rev
  end

  test "scope :draft works" do
    draft_rev     = @source.revisions.create!(version_number: 1, status: "draft")
    published_rev = @source.revisions.create!(version_number: 2, status: "published")

    drafts = KnowledgeRevision.draft
    assert_includes     drafts, draft_rev
    assert_not_includes drafts, published_rev
  end

  test "published? returns correct value" do
    draft     = @source.revisions.create!(version_number: 1, status: "draft")
    published = @source.revisions.create!(version_number: 2, status: "published")

    assert_not draft.published?
    assert     published.published?
  end

  test "validates status inclusion" do
    revision = KnowledgeRevision.new(
      knowledge_source: @source,
      version_number:   1,
      status:           "bogus"
    )
    # DB check constraint catches this; ActiveRecord validation also adds error
    assert_not revision.valid?
  end

  test "defaults status to draft" do
    revision = @source.revisions.create!(version_number: 1)
    assert_equal "draft", revision.status
  end

  test "stores content_json as jsonb" do
    revision = @source.revisions.create!(
      version_number: 1,
      status:         "published",
      content_json:   { question: "What time?", answer: "9 AM" }
    )
    assert_equal "What time?", revision.content_json["question"]
  end
end
