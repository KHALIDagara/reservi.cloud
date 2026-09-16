require "test_helper"

class Knowledge::SearchTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:alpha)
    @agent   = agents(:alpha_alice_human)

    # ── shared published source ────────────────────────────
    @shared_source = KnowledgeSource.create!(
      account: @account,
      title:   "Gardening FAQ",
      kind:    "qa",
      shared:  true
    )
    @shared_rev = @shared_source.revisions.create!(
      version_number: 1,
      status:         "published",
      content_json:   { question: "Best time to water?", answer: "Early morning" },
      raw_text:       "Water plants in the early morning to reduce evaporation."
    )

    # ── restricted published source (not shared) ───────────
    @restricted_source = KnowledgeSource.create!(
      account: @account,
      title:   "Internal Protocol",
      kind:    "document",
      shared:  false
    )
    @restricted_rev = @restricted_source.revisions.create!(
      version_number: 1,
      status:         "published",
      content_json:   { topic: "Escalation", steps: "Notify manager immediately" },
      raw_text:       "Escalation procedure: notify manager immediately."
    )

    # ── draft source (should never appear) ─────────────────
    @draft_source = KnowledgeSource.create!(
      account: @account,
      title:   "Draft Policy",
      kind:    "document",
      shared:  true
    )
    @draft_source.revisions.create!(
      version_number: 1,
      status:         "draft",
      content_json:   { text: "Draft content about watering" },
      raw_text:       "Draft: watering schedule is under review."
    )
  end

  test "returns empty results for blank query" do
    result = Knowledge::Search.call(account: @account, agent: @agent, query: "")
    assert_equal [], result[:results]
    assert_equal "", result[:query]
  end

  test "returns empty results for whitespace-only query" do
    result = Knowledge::Search.call(account: @account, agent: @agent, query: "   ")
    assert_equal [], result[:results]
  end

  test "finds matching shared knowledge in raw_text" do
    result = Knowledge::Search.call(account: @account, agent: @agent, query: "evaporation")
    assert_equal 1, result[:results].length
    assert_equal "Gardening FAQ", result[:results].first[:source_title]
  end

  test "finds matching shared knowledge in content_json" do
    result = Knowledge::Search.call(account: @account, agent: @agent, query: "Best time")
    assert_equal 1, result[:results].length
    assert_equal "Gardening FAQ", result[:results].first[:source_title]
  end

  test "returns snippet around query term" do
    result = Knowledge::Search.call(account: @account, agent: @agent, query: "morning")
    assert_equal 1, result[:results].length
    snippet = result[:results].first[:snippet]
    assert_includes snippet.downcase, "morning"
  end

  test "respects MAX_RESULTS limit" do
    # create 12 published sources with matching content
    12.times do |i|
      source = KnowledgeSource.create!(
        account: @account,
        title:   "Doc #{i}",
        kind:    "document",
        shared:  true
      )
      source.revisions.create!(
        version_number: 1,
        status:         "published",
        raw_text:       "This is document number #{i} about watering plants."
      )
    end

    result = Knowledge::Search.call(account: @account, agent: @agent, query: "watering")
    assert result[:results].length <= Knowledge::Search::MAX_RESULTS,
      "Expected at most #{Knowledge::Search::MAX_RESULTS}, got #{result[:results].length}"
  end

  test "restricted source not visible without grant" do
    result = Knowledge::Search.call(account: @account, agent: @agent, query: "escalation")
    assert_equal [], result[:results],
      "Restricted source should not appear without explicit grant"
  end

  test "restricted source visible with active grant" do
    AgentKnowledgeGrant.create!(
      account:           @account,
      agent:             @agent,
      knowledge_source:  @restricted_source,
      active:            true
    )

    result = Knowledge::Search.call(account: @account, agent: @agent, query: "escalation")
    assert_equal 1, result[:results].length
    assert_equal "Internal Protocol", result[:results].first[:source_title]
  end

  test "restricted source not visible with inactive grant" do
    AgentKnowledgeGrant.create!(
      account:           @account,
      agent:             @agent,
      knowledge_source:  @restricted_source,
      active:            false
    )

    result = Knowledge::Search.call(account: @account, agent: @agent, query: "escalation")
    assert_equal [], result[:results],
      "Inactive grant should not grant access"
  end

  test "draft revisions never appear" do
    result = Knowledge::Search.call(account: @account, agent: @agent, query: "watering schedule")
    assert_equal [], result[:results],
      "Draft revisions should never appear in search results"
  end

  test "case-insensitive search" do
    result = Knowledge::Search.call(account: @account, agent: @agent, query: "EVAPORATION")
    assert_equal 1, result[:results].length
    assert_equal "Gardening FAQ", result[:results].first[:source_title]
  end

  test "returns source metadata" do
    result = Knowledge::Search.call(account: @account, agent: @agent, query: "evaporation")
    entry  = result[:results].first
    assert_equal "Gardening FAQ",   entry[:source_title]
    assert_equal "qa",             entry[:source_kind]
    assert_equal 1,                entry[:version]
    assert entry[:snippet].present?
  end

  test "tenant isolation — does not find sources from other accounts" do
    beta_account = accounts(:beta)
    beta_source  = KnowledgeSource.create!(
      account: beta_account,
      title:   "Beta FAQ",
      kind:    "qa",
      shared:  true
    )
    beta_source.revisions.create!(
      version_number: 1,
      status:         "published",
      raw_text:       "Water plants at sunset in beta protocol."
    )

    result = Knowledge::Search.call(account: @account, agent: @agent, query: "sunset")
    assert_equal [], result[:results],
      "Should not see knowledge from other accounts"
  end
end
