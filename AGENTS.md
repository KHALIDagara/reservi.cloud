# Reservi — Agent Operating Manual

This file is the first instruction source for any AI agent or engineer working in this repository.

Reservi is intentionally designed so that a capable coding agent can take a well-formed goal, inspect the system, plan a small coherent change, implement it, prove it, review it, and update durable context without requiring constant human micromanagement.

The objective is not autonomous code generation. The objective is **autonomous, evidence-driven engineering inside a stable product and architectural model**.

---

## 1. Read this before touching code

For every non-trivial task:

1. Read this file and any closer `AGENTS.md` in the directory you are modifying.
2. Load the OpenCode skill `reservi-context`.
3. Read the relevant durable docs under `docs/`.
4. Inspect the actual repository and existing tests.
5. Identify the product behavior and invariants affected.
6. Plan the smallest coherent vertical change.
7. Implement and verify it.
8. Review the entire diff before claiming completion.

Never implement from a remembered conversation alone. Repository code and checked-in docs are the current source of truth.

If code and docs disagree, do not silently choose one. Determine which is stale, preserve user-facing behavior/invariants, and update the stale source deliberately.

---

## 2. Product north star

Reservi is a **mobile-first, conversation-centric CRM and service operations system**.

Its job is to turn an incoming customer conversation into correctly understood, correctly routed, scheduled, and completed service with as little friction and bookkeeping as possible.

The canonical operational loop is:

```text
incoming message
    ↓
conversation/customer context
    ↓
qualification / intent
    ↓
routing & ownership
    ↓
human + AI collaboration
    ↓
booking / commitment
    ↓
service execution
    ↓
completion / follow-up
```

The CRM should maintain itself as a side effect of real work.

Operators should not have to update redundant CRM records merely to keep the system current.

---

## 3. Core product truths

These are design anchors, not optional implementation suggestions.

### 3.1 A lead is the conversation

Do not create `Lead`, `Opportunity`, `Deal`, generic `Activity`, or similar traditional CRM abstractions simply because Salesforce/HubSpot/etc. have them.

The conversation itself carries the operational customer context: messages, current state, assignment, qualification, notes, booking context, history, and AI context.

A new concept must justify an independent lifecycle and durable truth.

### 3.2 Conversation is the operational center

Most operator actions should be reachable from the conversation experience without navigating a maze of CRM modules.

The system should feel closer to a shared inbox + operational workspace than to enterprise CRM data-entry software.

### 3.3 Humans and AI share the Agent abstraction

A human operator and an AI operator participate in the same conceptual system.

Both may, subject to permissions/capabilities:

- receive assignments;
- read conversation context;
- reply;
- add internal notes;
- update qualification;
- transition operational state;
- create/manage bookings;
- hand off work.

AI-specific runtime configuration belongs behind capabilities/instructions/provider integration, not in a parallel CRM architecture.

### 3.4 One current owner, truthful history

A conversation normally has one current owner at a time.

Reassignment must be clear and race-safe, and assignment history must remain truthful.

### 3.5 Teams are operational routing units

Teams group agents and participate in routing, workload distribution, escalation, and access.

Do not create a generalized workflow engine to represent simple routing rules prematurely.

### 3.6 Booking is part of the conversation flow

The calendar is not a detached product. Booking is the commitment produced by the conversation/qualification process.

Operators should be able to move from conversation to available slot to confirmed booking quickly.

### 3.7 Mobile first

Many service operators work from phones.

Every important workflow must remain usable on a narrow viewport. Desktop enhancements must not become required for basic operation.

---

## 4. Engineering north star

**ONE ENGINE, ONE GOAL.**

Favor one coherent Rails application over frontend/backend fragmentation and distributed services.

The default architecture is:

- Ruby on Rails monolith;
- PostgreSQL for durable truth;
- server-rendered HTML;
- Turbo Drive / Turbo Frames / Turbo Streams;
- Stimulus for local browser behavior;
- Active Job for asynchronous work;
- explicit adapters for external providers;
- database constraints for durable invariants;
- system tests for critical workflows.

The actual dependency versions in the repository are authoritative once bootstrapped.

---

## 5. Simplicity rules

Prefer the simplest design that preserves truth and enables likely near-term change.

Default preference order:

1. Existing concept.
2. Attribute/association/scope.
3. Clear model/domain method.
4. Small plain Ruby object when behavior truly has no natural model owner.
5. Dedicated operation/service only when orchestration is genuinely multi-entity and naming it improves clarity.
6. New infrastructure only after a current requirement proves it necessary.

Avoid by default:

- microservices;
- separate SPA;
- GraphQL between our own UI and Rails;
- CQRS;
- event sourcing;
- command buses;
- repository layers;
- DTO layers for internal calls;
- service/interactor explosion;
- callback-driven business workflows;
- generic workflow engines;
- speculative plugin frameworks;
- duplicated state in JavaScript;
- caches used as primary truth.

Every abstraction must pay rent now.

---

## 6. Planning protocol

Before implementation, reduce the task to observable behavior.

For each change identify:

- actor;
- trigger;
- preconditions;
- expected visible result;
- persisted changes;
- side effects;
- authorization requirements;
- invariants at risk;
- failure behavior;
- acceptance criteria;
- proof/tests.

Then inspect the existing implementation path before designing anything new.

Trace, as relevant:

```text
route
→ controller/request boundary
→ domain/model behavior
→ database constraints
→ job/integration boundary
→ Turbo/view/Stimulus behavior
→ tests
```

Do not write a plan that assumes files/classes that do not exist.

---

## 7. Implementation protocol

Keep changes vertical and bounded.

A useful feature slice usually contains all required layers to make one behavior actually work, rather than adding large horizontal frameworks for future work.

During implementation:

- keep tenant/account scope explicit;
- use transactions/locking for race-sensitive state;
- design jobs/webhooks for retries and duplicate delivery;
- avoid long database transactions across network calls;
- keep provider details at adapters;
- validate AI-generated actions as untrusted input;
- prefer server-rendered truth over client duplication;
- add indexes/constraints that match the real access/invariant needs;
- preserve historical truth rather than overwriting it destructively;
- do not refactor unrelated code unless it blocks correctness.

---

## 8. Testing and proof protocol

A feature is not done because the code compiles or a unit test passes.

Use the lowest useful layer and add end-to-end proof where integration matters.

Expected hierarchy:

```text
domain/model tests
    ↓
request/integration tests
    ↓
job/integration-boundary tests
    ↓
system/browser tests for critical workflows
```

Always consider tests for:

- tenant isolation;
- authorization;
- duplicate webhook delivery;
- idempotent retries;
- assignment races;
- booking conflicts/races;
- stale state;
- provider failure;
- human/AI capability restrictions.

For a bug, reproduce first and add a regression test unless there is a strong reason not to.

For user-visible changes, exercise the real/system browser flow when feasible.

Never say a test, command, browser flow, or review was performed unless it actually was.

See `docs/testing.md`.

---

## 9. Debugging protocol

Do not thrash.

Use:

```text
REPRODUCE
→ OBSERVE
→ TRACE
→ ISOLATE
→ HYPOTHESIZE
→ TEST HYPOTHESIS
→ FIX ROOT CAUSE
→ ADD REGRESSION TEST
→ VERIFY
```

Forbidden shortcuts:

- random edits;
- broad rescues that swallow errors;
- disabling constraints to make code pass;
- arbitrary sleeps for race conditions;
- deleting valid failing tests;
- blaming providers/dependencies without evidence.

---

## 10. Data and multi-tenancy safety

Tenant isolation is a hard invariant.

Every account-owned read/write path must make it impossible for one account to access another account's data through guessed IDs, nested routes, jobs, websocket/Turbo broadcasts, search, exports, or provider callbacks.

Do not depend on UI hiding for authorization.

Prefer scoping from the current account/root aggregate rather than globally finding a record and checking ownership later.

Use database foreign keys and appropriate uniqueness scopes.

---

## 11. External integrations

Assume providers are slow, duplicated, delayed, out of order, and occasionally wrong.

For incoming webhooks:

- authenticate/signature-check when supported;
- resolve account/channel through configured integration identity;
- persist/derive a stable external event ID;
- process idempotently;
- acknowledge quickly;
- move slow work to jobs;
- retain debuggable correlation data.

For outgoing requests:

- use provider idempotency keys when available;
- make retry behavior explicit;
- avoid duplicate customer-visible messages;
- persist remote IDs needed for reconciliation;
- never hold a DB transaction open while waiting on a remote provider unless there is an exceptional documented reason.

---

## 12. AI behavior inside Reservi

LLM output is untrusted input.

An AI agent may propose or execute only actions allowed by server-side capabilities and domain rules.

Prompts do not grant permissions.

Always validate:

- account scope;
- actor capability;
- target conversation/booking state;
- structured action fields;
- domain invariants;
- approval requirements for sensitive actions.

The important operational action should be auditable enough to answer: who/what acted, on which conversation, using what capability, and what changed.

---

## 13. Git discipline

Before editing:

```bash
git status
```

After editing:

```bash
git diff
```

Before declaring completion, review the entire diff as if it came from another engineer.

Keep commits focused and reversible.

Do not overwrite unrelated local changes.

Do not rewrite history unless explicitly requested.

---

## 14. Documentation discipline

Durable docs describe durable truth, not every implementation detail.

Update:

- `docs/product-requirements.md` when product behavior/scope changes;
- `docs/architecture.md` when architectural decisions/boundaries change;
- `docs/domain-model.md` when domain concepts/relationships change;
- `docs/invariants.md` when a hard truth is added/changed;
- `docs/testing.md` when verification doctrine changes.

Do not turn these files into chronological logs.

If a decision deserves its own rationale/history, add an ADR under `docs/decisions/`.

---

## 15. Definition of done

A task is complete only when all applicable statements are true:

- the requested behavior exists;
- the design fits the Reservi mental model;
- relevant invariants are preserved;
- account isolation and authorization are correct;
- race/retry/idempotency risks were considered;
- appropriate tests were added/updated;
- relevant tests pass;
- user-visible behavior was exercised when appropriate;
- the final diff was reviewed;
- durable docs match durable reality;
- unverified assumptions are disclosed.

Prefer a smaller fully proven change over a larger half-proven one.

---

## 16. OpenCode agent usage

The project defines:

- `reservi` — primary orchestrator/engineer;
- `architect` — read-only architecture/domain critic;
- `implementer` — bounded implementation specialist;
- `verifier` — proof/testing specialist;
- `reviewer` — independent read-only final reviewer.

Useful skills include:

- `reservi-context`;
- `feature-execution`;
- `rails-engineering`;
- `database-integrity`;
- `integration-safety`;
- `testing`;
- `debugging`.

The primary agent may delegate, but delegation never replaces responsibility for the final integrated result.
