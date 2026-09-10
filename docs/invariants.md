# Reservi Invariants

These are hard product and engineering truths. Features may evolve, but these constraints must remain true unless a deliberate product/architecture decision explicitly changes them.

When a change can violate an invariant under concurrency, retries, malformed input, or unauthorized access, application-level happy-path checks are not sufficient.

---

## 1. Tenancy and authorization

### INV-001 — Account isolation

A tenant/account must never be able to read, mutate, search, export, subscribe to, or receive realtime data belonging to another account.

This applies to:
- controllers;
- nested routes;
- jobs;
- Turbo/realtime broadcasts;
- search;
- exports;
- webhook processing;
- attachments;
- AI/tool execution.

### INV-002 — Authorization is server-side

UI visibility never grants or removes authority by itself.

Every protected mutation must be authorized server-side using current account/actor context.

### INV-003 — External payloads cannot choose tenant context

An inbound provider event must resolve its Account through trusted integration/channel configuration, not by trusting an arbitrary tenant/account identifier in the incoming payload.

---

## 2. Conversation and CRM truth

### INV-010 — The conversation is the lead

Reservi must not maintain a second canonical lead/opportunity/deal record containing the same operational truth as Conversation.

Projections/reporting records may exist, but they cannot become competing sources of truth.

### INV-011 — One authoritative conversation state

A Conversation has one authoritative current operational state.

Historical state/audit records may describe transitions but cannot disagree about what is current.

### INV-012 — One authoritative current owner

A Conversation normally has at most one authoritative current Agent owner at a time.

Assignment history may contain many records; current ownership must remain unambiguous.

### INV-013 — Reassignment preserves history

Reassigning a Conversation changes current ownership without destroying who previously owned it, when, and—where captured—who/what initiated the change.

### INV-014 — Internal notes never become customer messages

A Note marked/internal by concept must never be sent through a customer-facing channel accidentally.

---

## 3. Agent invariants

### INV-020 — Human and AI actors obey the same domain authority

An AI Agent cannot bypass an invariant or permission that applies to a human Agent simply because its action originated from a prompt/tool call.

### INV-021 — Prompts do not grant capabilities

AI instructions may request actions, but server-side capability/authorization determines whether the action can execute.

### INV-022 — Significant actions are attributable

Customer-visible messages, assignments, booking mutations, and other operationally significant changes should be attributable to an Agent/system actor to the degree necessary for reliable operations and auditability.

---

## 4. Messaging invariants

### INV-030 — Inbound duplicate delivery is safe

If a provider delivers the same inbound event/message more than once, Reservi must not create duplicate customer messages or duplicate downstream irreversible actions.

### INV-031 — Outbound retries must not casually duplicate customer-visible messages

Retryable outbound processing must use stable operation/provider identities or equivalent guards so network/job retry does not result in duplicate sends whenever provider semantics allow prevention/reconciliation.

### INV-032 — Message ownership cannot cross conversations/accounts

A persisted Message belongs to exactly the intended Conversation and tenant context.

### INV-033 — Provider state is not hidden domain truth

Provider delivery identifiers/statuses can inform Message delivery state, but core Conversation/Booking ownership/state must not silently depend on provider-only state that Reservi cannot reconcile.

---

## 5. Booking invariants

### INV-040 — Booking time is unambiguous

Persisted booking instants are represented consistently, with timezone used for interpretation/display rather than ambiguous local timestamps.

### INV-041 — Resource conflicts respect scheduling rules

If the product defines a resource/provider/location as incapable of serving overlapping bookings, two concurrent booking attempts must not both commit a conflicting confirmed booking.

The database/transaction strategy must protect this, not just a pre-insert availability check.

### INV-042 — Conversation and calendar views share booking truth

A Booking shown in the conversation and the calendar must resolve to the same authoritative record/state.

Do not duplicate booking status independently in both surfaces.

### INV-043 — Booking history/state changes are truthful

Reschedule/cancel/complete operations must not erase the operational facts required to understand what happened.

---

## 6. Qualification invariants

### INV-050 — Qualification values conform to their definitions

A structured qualification value must validate against its field definition/type/options/constraints before becoming authoritative.

### INV-051 — AI-extracted qualification is not exempt from validation

AI output is untrusted input and follows the same validation rules as human/API input.

### INV-052 — Current qualification truth is not duplicated arbitrarily

If qualification values are projected elsewhere for search/reporting, the projection is not a competing writable source of truth.

---

## 7. Data integrity invariants

### INV-060 — Foreign relationships are valid

Durable ownership/association relationships use database foreign keys where practical and appropriate.

### INV-061 — Race-sensitive uniqueness is database-enforced

When duplicate rows would violate durable truth, use a unique/exclusion/check constraint or equivalent database mechanism where possible.

Model-level uniqueness validation alone is insufficient.

### INV-062 — Known durable truth is modeled explicitly

Do not hide stable, queryable domain truth entirely inside unvalidated JSON solely to avoid schema design.

JSON/JSONB is acceptable for provider-shaped or genuinely flexible metadata.

### INV-063 — Historical records are not rewritten to fake the present

Assignment/history/audit records describe what happened. Current fields/projections describe what is current.

Do not mutate history to make current state look simpler.

---

## 8. Job and integration invariants

### INV-070 — Retryable jobs are idempotent or explicitly protected

A job that can retry must either be naturally idempotent or contain guards/idempotency identity that make repeat execution safe.

### INV-071 — Slow external calls do not silently define transactional atomicity

Do not assume a database write and external provider mutation are atomic.

Model/reconcile intermediate failure explicitly where correctness requires it.

### INV-072 — Provider credentials/secrets never enter source control or normal logs

Secrets belong in appropriate runtime credential/configuration storage.

### INV-073 — Integration adapters normalize before entering the domain

Core domain code should not require raw provider payload structures to perform ordinary business logic.

---

## 9. UI invariants

### INV-080 — Server truth survives refresh

Refreshing the page may change presentation but must restore the same authoritative domain truth.

Critical domain correctness must not depend on ephemeral JavaScript state/event ordering.

### INV-081 — Core workflows are mobile-usable

Inbox, conversation, reply, assignment/handoff, qualification, and booking core operations must remain usable on a phone-sized viewport.

### INV-082 — Realtime updates cannot leak tenants

Turbo/WebSocket/realtime subscription identifiers and broadcasts must maintain account isolation.

---

## 10. Simplicity invariants

### INV-090 — No abstraction without present value

A new architectural layer/framework must solve a current problem, not only an imagined future one.

### INV-091 — One source of truth per domain fact

Caches, search indexes, UI projections, histories, and provider mirrors may exist, but one authoritative source must be identifiable for each important fact.

### INV-092 — Common feature paths remain traceable

A capable engineer/AI agent should be able to trace a normal request from route/request boundary through domain persistence and response without traversing unnecessary indirection layers.

---

## 11. How to use invariants during implementation

For every meaningful feature, explicitly ask:

1. Which invariants are touched?
2. Can concurrent requests violate them?
3. Can job/webhook retry violate them?
4. Can stale UI state violate them?
5. Can an unauthorized or AI actor violate them?
6. What database constraint protects them?
7. What test proves them?

If an invariant changes legitimately, update this document in the same change and explain the new product/architecture rationale.
