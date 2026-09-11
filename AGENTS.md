# Reservi — Agent Operating Manual

This is the first instruction source for any AI agent or engineer working in this repository.

Reservi is intentionally designed so a capable coding agent can take a goal, inspect the system, plan a small coherent change, implement it, prove it, review it, and update durable context without constant human micromanagement.

The objective is **autonomous, evidence-driven engineering inside a stable product model**.

---

## 1. Mandatory orientation

For every non-trivial task:

1. Read this file and any closer `AGENTS.md`.
2. Load `reservi-context`.
3. For Flow/Stage/Field/Catalog/Item/Appointment/Rule work, load `flow-engine`.
4. Read relevant durable docs under `docs/`, including `gap-audit.md` and `implementation-plan.md` when planning or choosing implementation work.
5. Inspect actual code/schema/tests before designing.
6. Identify affected invariants.
7. Plan the smallest coherent vertical change.
8. Implement, verify, review the full diff.

Never implement from remembered conversation alone. Checked-in code and docs are current truth.

If code and docs conflict, surface the conflict and resolve it deliberately.

---

## 2. Product north star

Reservi is a **mobile-first, conversation-centric CRM and operations system**.

Its purpose is to help a customer request move from conversation to real-world outcome with minimal friction and bookkeeping.

The CRM maintains itself as a side effect of useful work.

The fundamental runtime model is:

```text
Conversation state
      ↓
Current Stage
      ↓
Humans + AI + Rules change state
      ↓
Completion predicate becomes true
      ↓
Next Stage
```

A lead is the Conversation. Do not recreate a traditional Lead / Opportunity / Deal tree.

---

## 3. Canonical ontology — do not drift from this casually

### 3.1 Conversation

The lead, customer request, and running process instance.

Conversation is the operational root and exposes current Stage, Customer, owner/team, Fields, selected Items, Appointments, Messages/Notes, and history.

### 3.2 Flow / Stage

A Flow is an ordered set of configurable Stages.

A Stage is not a decorative CRM status.

```text
Stage = Blocks + Rules + Completion Predicate
```

Think:

> Stage = Work + Gate

The Stage declares what can/should happen now and what must become true before progression.

### 3.3 Field

A structured fact.

Use Customer-scoped Fields for durable profile facts and Conversation-scoped Fields for request-specific facts.

Examples: city, budget, surface, urgency, language.

### 3.4 Catalog / Item

A `Catalog` is a collection of reusable selectable business things.

An `Item` is the universal selectable entity inside it.

Examples:

```text
Catalog: Services    -> Item: Garden Maintenance
Catalog: Cars        -> Item: Range Rover Evoque
Catalog: Properties  -> Item: Villa Agdal
Catalog: Rooms       -> Item: Treatment Room 2
```

All Items share the same fundamental shape:

- title;
- images;
- description;
- price;
- typed additional attributes;
- active/archive state.

**Do not create separate core Service, Car, Room, Property, Resource, ResourceType workflow abstractions when Catalog/Item is sufficient.**

### 3.5 ItemSelection

A configured Catalog Selector places one or more Items into Conversation state under a stable selector key such as `vehicle`, `property`, or `requested_service`.

Selection means selection only.

It does **not** inherently mean reserved, scheduled, owned, exclusive, or booked.

### 3.6 Appointment

The canonical scheduling entity.

Appointment is a time-bound commitment associated with a Conversation.

It is independent from Item selection.

Never assume:

```text
Appointment requires Service
Appointment requires Item
Item must be bookable
Item selection must happen before Appointment
```

All of these must remain possible:

```text
Appointment without Item selection
Item selection without Appointment
Appointment before Item selection
Item selection before Appointment
multiple Items
multiple Appointments
no Catalog at all
```

An operator can understand that a Pickup Appointment concerns the selected Range Rover because both appear in the same Conversation context. Reservi does not need a `bookable` Item flag to infer this.

If item-level reservation/capacity becomes a real requirement later, model it explicitly then. Do not smuggle it into Catalog Item semantics prematurely.

### 3.7 Rule

```text
Rule = Predicate + Actions
```

Example:

```text
IF field("city") == "Marrakech"
THEN assign Ahmed
```

The same predicate model should serve completion, routing/assignment, and other supported conditions.

Rules call normal domain operations; they do not bypass invariants.

---

## 4. The extension formula

For a future first-class feature, ask whether it can expose:

```text
Feature = State + Controls + Predicates + Actions
```

Example Quote:

```text
State: quote.status, quote.total
Control: Quote Builder
Predicates: quote exists / accepted
Actions: create_quote / send_quote
```

Then Stages can compose it without adding Quote-specific transition logic to the central Flow engine.

Before creating a new domain model, ask:

1. Is it merely a fact? -> Field.
2. Is it a reusable selectable business thing? -> Catalog Item.
3. Is it a time-bound commitment? -> Appointment.
4. Otherwise, what independent lifecycle/invariant proves a new concept is needed?

---

## 5. Human and AI symmetry

Humans and AI share the conceptual `Agent` abstraction.

Both operate on the same Conversation truth and current Stage requirements, subject to capabilities/permissions.

Do not encode the real business flow only inside an AI prompt.

The durable Flow/Stage configuration is authoritative process intent. The AI prompt helps the model operate inside it.

AI output is untrusted input and must pass normal server-side validation and authorization.

---

## 6. Engineering north star

**ONE ENGINE, ONE GOAL.**

Default architecture:

- Ruby on Rails monolith;
- PostgreSQL;
- server-rendered HTML;
- Turbo Drive / Frames / Streams;
- Stimulus for local browser behavior;
- Active Job;
- Active Storage where appropriate;
- explicit integration adapters;
- database constraints for durable invariants;
- system tests for critical workflows.

Prefer Rails conventions and boring technology.

Avoid by default:

- microservices;
- separate SPA;
- GraphQL between our own frontend/backend;
- CQRS/event sourcing;
- command buses;
- repository/DTO layers;
- service/interactor explosion;
- generic BPM/workflow engines;
- arbitrary scripting in Rules;
- universal Entity/Property/Relation schemas;
- duplicated JavaScript truth;
- caches as primary truth.

Every abstraction must pay rent now.

---

## 7. Flow-engine engineering rules

When implementing Flow behavior:

- use one normalized predicate model;
- use stable IDs/keys, never mutable labels as logic identity;
- keep Stage completion server-side;
- make Stage advancement race-safe/idempotent;
- make irreversible Rule Actions idempotent/protected;
- prevent Rule/action loops explicitly;
- make significant automation explainable;
- avoid scattered Stage transitions hidden in callbacks;
- define what active configuration edits do to in-flight Conversations;
- reject cross-Account references in configuration;
- never execute arbitrary user code.

Prefer ordered Stages initially. Do not build arbitrary graph branches/loops/timers/parallel workflow infrastructure until a real requirement demands it.

---

## 8. Planning protocol

Before implementation reduce the task to observable behavior.

Identify:

- actor;
- trigger;
- current Flow/Stage context;
- preconditions;
- expected visible result;
- persisted truth;
- predicates;
- Actions/side effects;
- authorization;
- invariants;
- concurrency/retry risk;
- configuration compatibility;
- acceptance/proof.

Trace existing code as relevant:

```text
route
-> controller/request boundary
-> domain operation/model
-> database constraints
-> Flow evaluation
-> jobs/integrations
-> Turbo/view/Stimulus
-> tests
```

Do not plan files/classes that do not exist without first proving they are needed.

---

## 9. Implementation protocol

Keep changes vertical and bounded.

During implementation:

- keep Account scope explicit;
- use transactions/locking for race-sensitive state;
- make jobs/webhooks retry-safe;
- avoid network calls inside long DB transactions;
- keep provider details at adapters;
- validate AI Actions like any external input;
- prefer server-rendered truth;
- add indexes/constraints matching real access/invariants;
- preserve historical truth;
- avoid unrelated refactors.

For configurable state, do not use unvalidated JSON merely for convenience. Structured JSON/AST is fine when the shape is genuinely dynamic and strongly validated behind a domain API.

---

## 10. Testing and proof

A feature is not done because code compiles or a unit test passes.

Expected proof hierarchy:

```text
predicate/domain tests
    ↓
request/integration tests
    ↓
job/integration-boundary tests
    ↓
system/browser tests
    ↓
targeted concurrency tests where truth can race
```

Always consider:

- tenant isolation;
- duplicate events/retries;
- repeated Rule evaluation;
- duplicate Rule Actions;
- concurrent Stage advancement;
- assignment races;
- explicit Appointment conflict rules;
- stale state;
- active configuration changes;
- AI capability restrictions.

Architecture regression scenarios must include:

- Appointment with no Catalog/Item;
- Item selection with no Appointment;
- Appointment before Item selection;
- Item selection before Appointment;
- Services/Cars/Properties all represented as Catalog Items through the same path.

See `docs/testing.md`.

---

## 11. Debugging protocol

Do not thrash.

```text
REPRODUCE
-> OBSERVE
-> TRACE
-> ISOLATE
-> HYPOTHESIZE
-> TEST
-> FIX ROOT CAUSE
-> REGRESSION TEST
-> VERIFY
```

Never hide a defect by swallowing errors, weakening valid tests, disabling constraints, or adding arbitrary sleeps.

---

## 12. Data and integration safety

Tenant isolation is hard.

Provider events are assumed duplicated, delayed, reordered, and fallible.

Incoming integrations:

- verify/authenticate where supported;
- resolve Account through trusted integration configuration;
- deduplicate stable provider identity;
- normalize before domain entry;
- acknowledge quickly;
- enqueue slow work.

Outgoing work:

- use stable operation identity;
- define retries;
- prevent duplicate customer-visible Messages;
- persist remote IDs for reconciliation where useful.

---

## 13. Git and review discipline

Before editing:

```bash
git status
```

After editing:

```bash
git diff
```

Before completion:

- run focused/relevant tests;
- exercise user-visible behavior when applicable;
- inspect the complete diff as another engineer would;
- ask `reviewer` to inspect meaningful changes independently;
- update durable docs when durable truth changed.

Never claim a test/browser flow/review ran unless it actually did.

---

## 14. Documentation discipline

Durable docs:

- `docs/product-requirements.md` — what Reservi should do;
- `docs/architecture.md` — system boundaries/shape;
- `docs/domain-model.md` — canonical concepts;
- `docs/flow-engine.md` — Stage/Rule/Catalog/Appointment composition model;
- `docs/invariants.md` — truths that may not be broken;
- `docs/testing.md` — proof strategy;
- `docs/gap-audit.md` — audited gaps, concrete decisions and deferred boundaries;
- `docs/implementation-plan.md` — dependency tasks, acceptance gates and evidence ledger.

Documentation decisions are not implemented features. Check the actual repository before choosing a task; mark a task VERIFIED only with a commit and real proof. The initial baseline contains specifications only.

These are not changelogs.

---

## 15. Definition of done

A task is complete only when applicable statements are true:

- requested behavior exists;
- it fits the canonical Reservi ontology;
- no unnecessary vertical-specific abstraction was added;
- relevant invariants remain true;
- tenant/authorization rules hold;
- retries/concurrency were considered;
- tests prove meaningful behavior;
- UI flow was exercised where applicable;
- diff was reviewed;
- durable docs match reality;
- remaining assumptions/risks are disclosed.

Prefer a smaller fully proven change over a larger half-proven one.

---

## 16. OpenCode agents

- `reservi` — primary orchestrator/engineer;
- `architect` — architecture/domain critic;
- `implementer` — bounded implementation specialist;
- `verifier` — proof/testing specialist;
- `reviewer` — independent read-only review.

Useful skills:

- `reservi-context`;
- `flow-engine`;
- `feature-execution`;
- `repository-navigation`;
- `rails-engineering`;
- `database-integrity`;
- `integration-safety`;
- `testing`;
- `debugging`;
- `security`.
