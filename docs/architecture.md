# Reservi Architecture

## 1. Architectural objective

Reservi should remain a compact, legible, robust monolith that allows humans and AI agents to make changes safely without reconstructing the system's mental model every time.

The architecture optimizes for:

- one coherent domain;
- low conceptual overhead;
- strong database truth;
- server-driven UI;
- explicit integration boundaries;
- safe concurrency/retries;
- easy local reasoning;
- straightforward testing;
- gradual scaling without premature distribution.

The architecture is deliberately biased toward Rails conventions and PostgreSQL rather than internal frameworks.

---

## 2. System shape

Default deployment shape:

```text
┌──────────────────────────────────────────────┐
│                 Rails Monolith               │
│                                              │
│  HTTP / Turbo / Webhooks                     │
│          │                                   │
│          ▼                                   │
│  Controllers / Request boundaries            │
│          │                                   │
│          ▼                                   │
│  Domain models + focused operations          │
│          │                                   │
│          ├─────────────┐                     │
│          ▼             ▼                     │
│     PostgreSQL      Active Job               │
│                         │                    │
│                         ▼                    │
│                 Integration adapters         │
│                 (WhatsApp/AI/etc.)           │
│                                              │
│  Views + Turbo + Stimulus                    │
└──────────────────────────────────────────────┘
```

One application should own the core domain, web UI, operational jobs, and integration boundaries unless a demonstrated scaling/operational requirement forces a split.

---

## 3. Preferred technology posture

### Application

- Ruby on Rails, current project-selected stable version.
- PostgreSQL.
- Hotwire (Turbo + Stimulus).
- Active Job.
- Active Storage where attachments are required.
- Rails-native/server-rendered authentication and authorization patterns unless requirements dictate otherwise.

### Optional infrastructure

Add only when required by actual deployment/load:

- Redis or a dedicated job backend;
- external object storage;
- error monitoring/observability;
- dedicated search engine;
- realtime infrastructure beyond Rails defaults;
- external analytics warehouse.

The repository/Gemfile is authoritative once bootstrapped.

---

## 4. Boundary model

The system should have a small number of understandable boundaries.

### 4.1 HTTP boundary

Controllers handle:

- authentication context;
- account/tenant context;
- authorization;
- input parsing;
- invoking domain behavior;
- choosing HTML/Turbo/JSON response.

Controllers should not become the home of core business rules.

### 4.2 Domain boundary

Active Record models and focused domain operations own business truth.

Keep behavior close to the records whose state it protects.

Use a separate operation object only when orchestration genuinely spans several records/external steps and putting it on one model would misrepresent ownership.

Avoid one-service-per-controller-action patterns.

### 4.3 Persistence boundary

PostgreSQL owns durable truth and should enforce constraints that must survive races.

The database is not merely a serialization layer.

### 4.4 Integration boundary

Provider-specific transport/payload/status logic lives in adapters/modules/jobs near the edge.

Core models should not know whether a message came from Meta, Twilio, email, or another provider except through normalized concepts/identifiers that matter to the domain.

### 4.5 UI boundary

Rails renders server truth.

Turbo updates portions of the page and supports realtime/server-driven changes.

Stimulus owns browser-local interaction, not business truth.

---

## 5. Suggested application organization

Do not create these directories until there is code that needs them; this is a naming direction, not scaffolding work.

```text
app/
  models/
  controllers/
  views/
  jobs/
  helpers/
  javascript/controllers/

  # Introduce selectively when needed:
  operations/        # named multi-record domain use cases
  integrations/      # provider adapters / clients / normalization
  policies/          # if an explicit policy layer is adopted

lib/
  # infrastructure utilities only; do not exile domain logic here
```

Prefer fewer top-level concepts over a deep "enterprise" folder hierarchy.

---

## 6. Multi-tenancy

Account/organization is the primary tenancy boundary.

### Requirements

- Every tenant-owned record must have an unambiguous path to its account.
- Request handling establishes current account context explicitly.
- Queries should generally start from account-owned associations/scopes.
- Background jobs carry stable account/record identity and re-scope server-side.
- Webhook resolution derives account from configured channel/integration credentials, not untrusted payload tenant IDs.
- Turbo/realtime broadcasts must not leak cross-account data.
- Search/export/report paths remain tenant-scoped.

### Database posture

Use account-scoped uniqueness where uniqueness is business-local.

Where child records inherit account ownership through a parent, consider whether a direct `account_id` materially improves safety/querying; avoid blind denormalization, but do not force expensive/fragile joins just for purity.

---

## 7. Conversation-centric domain architecture

Conversation is the aggregate-like operational center, but avoid turning it into a God object.

Conversation should coordinate or reference:

- customer;
- channel;
- current team/owner;
- operational state;
- messages;
- qualification;
- notes;
- bookings;
- assignment/history.

Supporting models own their own local invariants and histories.

Do not duplicate a separate Lead/Opportunity tree alongside this structure.

---

## 8. Human/AI Agent architecture

The domain-level `Agent` represents something capable of operational work.

Possible implementation strategies may evolve, but the conceptual rule remains:

```text
Agent
 ├─ Human-backed
 └─ AI-backed
```

Differences belong in configuration/capabilities, not duplicated assignment/message/booking models.

A human-backed Agent can reference a user/membership identity.

An AI-backed Agent can reference runtime/instruction/provider configuration.

Server-side capability checks authorize actions regardless of actor type.

---

## 9. State modeling

Prefer compact explicit enums/state values over generalized workflow DSLs.

State transitions should:

- be named;
- validate preconditions;
- be authorized;
- run in a transaction when multiple durable changes must remain consistent;
- preserve required history;
- emit/schedule external side effects after durable truth is established where practical.

Do not use UI state as domain truth.

---

## 10. Assignment and routing architecture

Keep routing deterministic and explainable.

A practical evolution path:

1. explicit manual assignment;
2. default team routing;
3. simple rule-based routing;
4. round-robin/capacity-aware routing if required;
5. richer configurable routing only after real needs justify it.

The assignment operation must be safe under two simultaneous workers/users.

Use a current-owner representation optimized for inbox reads plus append-only/history records when history is required.

The exact schema is defined by implementation, but there must be one authoritative current assignment.

---

## 11. Booking/calendar architecture

Booking is durable domain truth in PostgreSQL.

Availability is derived from:

- service duration/buffers;
- provider/resource schedule;
- location constraints;
- exceptions/time off;
- existing committed bookings;
- timezone context.

Do not make a third-party calendar the hidden source of truth unless product requirements explicitly change ownership.

External calendar sync should be an integration/reconciliation concern.

Conflict rules must survive concurrency at the database/transaction level where necessary.

---

## 12. Messaging architecture

### Inbound

```text
provider webhook
→ authenticate webhook
→ resolve configured channel/account
→ deduplicate external event/message
→ normalize payload
→ resolve customer/conversation
→ persist message
→ update attention/recent activity
→ enqueue slow routing/AI/provider work as appropriate
→ return promptly
```

### Outbound

```text
agent requests reply
→ authorize actor/capability
→ persist local intent/message state
→ enqueue/send via provider adapter
→ persist provider ID/result
→ reconcile delivery callbacks
```

Exact ordering may vary by provider semantics, but duplicate customer-visible sends must be prevented.

Provider payloads should be retained only to the degree needed for debugging/reconciliation/privacy policy.

---

## 13. Background jobs

Use jobs when work:

- calls slow/unreliable external APIs;
- needs independent retries;
- performs expensive processing;
- sends notifications/messages;
- runs AI inference;
- reconciles provider state.

Jobs should be:

- idempotent;
- scoped to tenant/record identity;
- retry-safe;
- observable;
- small enough to reason about.

Do not encode critical ordering as an undocumented assumption between unrelated jobs.

---

## 14. Transaction and side-effect rules

Prefer this shape:

```text
validate/authorize
→ transactionally write local durable truth
→ commit
→ enqueue/perform external side effect
→ reconcile result
```

Avoid long network calls inside open DB transactions.

When a remote action and local write cannot be atomic, model the intermediate/reconciliation state explicitly instead of pretending distributed atomicity exists.

---

## 15. Idempotency

Idempotency is mandatory for retryable/external operations.

Sources of stable keys may include:

- provider event ID;
- provider message ID;
- generated operation UUID;
- unique logical composite key.

Use database uniqueness as the final guard where possible.

Do not rely solely on "check then insert" application logic.

---

## 16. Realtime and Turbo

Use realtime updates to improve shared-inbox/calendar awareness, not to create a second truth system.

Turbo broadcasts must:

- be tenant-safe;
- update identifiable server-rendered fragments;
- tolerate a refresh restoring correct state;
- not require fragile client event order to become correct.

If refresh fixes the UI, that is acceptable; if refresh changes domain truth, architecture is wrong.

---

## 17. Search

Start with PostgreSQL search/querying for operational use cases.

Add external search only after measured requirements such as:

- corpus size;
- latency;
- fuzzy/full-text sophistication;
- ranking;
- multi-field analytics

show that PostgreSQL is insufficient.

Search indexes are projections, never the source of authorization or durable truth.

---

## 18. Security architecture

### Authentication

Use mature Rails-compatible mechanisms. Keep session/token handling server-controlled.

### Authorization

Authorization is server-side and account-scoped.

AI and human actions pass through the same domain permission boundaries where possible.

### Secrets

Provider/API credentials never live in source control or logs.

### Attachments

Validate type/size/access. Serve through authorized or appropriately scoped URLs.

### Webhooks

Verify signatures/secrets when supported and rate-limit/guard exposed endpoints appropriately.

---

## 19. Observability

Prefer structured, correlated operational logs.

Useful fields:

- account ID;
- request ID;
- job ID;
- conversation ID;
- channel/integration ID;
- provider event/message ID;
- actor/agent ID;
- normalized operation/outcome.

Do not log secrets or unnecessary sensitive message content.

Add metrics/tracing based on actual operational needs rather than instrumentation theater.

---

## 20. Performance and scalability

Expected scaling principle: scale the monolith before splitting the domain.

Use:

- proper indexes;
- bounded/paginated message lists;
- eager loading;
- background jobs;
- multiple app/job processes;
- database connection discipline;
- caching only for measured hot paths;
- read replicas only when real read pressure requires them.

Tens or hundreds of agents/teams do not inherently require microservices.

Architecture distribution should be driven by operational boundaries that cannot be solved cleanly in the monolith, not by user count alone.

---

## 21. Migration strategy

Prefer additive evolution:

1. add new structure;
2. dual-read/write only if genuinely required;
3. backfill safely;
4. verify;
5. switch authoritative path;
6. enforce constraints;
7. remove obsolete structure later.

For ordinary small migrations, do not over-engineer staged rollouts; assess actual table size/risk.

Never put external API calls in migrations.

---

## 22. Architectural anti-pattern checklist

Challenge any change that introduces:

- duplicated lead/conversation state;
- globally scoped tenant-owned queries;
- business logic hidden in callbacks;
- giant Stimulus controllers with domain state;
- provider-specific columns scattered across core tables;
- "manager/service" classes with vague names;
- service objects that only wrap one model call;
- polymorphism used only to avoid naming a real concept;
- JSON blobs for known relational truth;
- application-only uniqueness for race-sensitive rules;
- network calls inside long DB transactions;
- jobs that are unsafe to retry;
- abstractions justified only by hypothetical future scale.

---

## 23. Architectural decision test

Before accepting a new abstraction, ask:

1. What current requirement forces this?
2. What existing concept cannot express it?
3. What invariant does it make easier to preserve?
4. What new failure modes/operations does it introduce?
5. Can a new engineer trace it quickly?
6. Can it be removed/replaced later?
7. Does it keep one source of truth?

If the answer is mostly "we may need it someday", do not add it yet.
