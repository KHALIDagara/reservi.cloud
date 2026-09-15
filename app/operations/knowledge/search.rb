module Knowledge
  class Search
    MAX_RESULTS = 10

    def self.call(account:, agent:, query:)
      new(account: account, agent: agent, query: query).call
    end

    def initialize(account:, agent:, query:)
      @account = account
      @agent   = agent
      @query   = query.to_s.strip
    end

    def call
      return { results: [], query: @query } if @query.blank?

      # Find knowledge sources accessible to this agent
      accessible_ids = accessible_source_ids

      revisions = KnowledgeRevision.published
        .joins(:knowledge_source)
        .where(knowledge_sources: { id: accessible_ids, account_id: @account.id })
        .where("knowledge_revisions.content_json::text ILIKE :q OR knowledge_revisions.raw_text ILIKE :q",
               q: "%#{sanitize_like(@query)}%")
        .limit(MAX_RESULTS)

      results = revisions.map do |rev|
        {
          source_title: rev.knowledge_source.title,
          source_kind:  rev.knowledge_source.kind,
          version:      rev.version_number,
          snippet:      extract_snippet(rev)
        }
      end

      { results: results, query: @query }
    end

    private

    def accessible_source_ids
      # All shared active sources + explicitly granted restricted sources
      shared  = @account.knowledge_sources.active.shared.pluck(:id)
      granted = @agent.knowledge_grants.active.pluck(:knowledge_source_id)
      (shared + granted).uniq
    end

    def extract_snippet(rev)
      text = rev.raw_text || rev.content_json.to_s
      idx  = text.downcase.index(@query.downcase)
      return text.truncate(200) unless idx

      start  = [idx - 60, 0].max
      finish = [idx + @query.length + 60, text.length].min
      text[start...finish]
    end

    # Basic LIKE-sanitization: escape _ and % characters in the user query
    def sanitize_like(value)
      value.gsub("%", "\\%").gsub("_", "\\_")
    end
  end
end