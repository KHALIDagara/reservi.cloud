# Reservi Invariants

These are hard product and engineering truths. Features may evolve, but these constraints must remain true unless a deliberate product/architecture decision explicitly changes them.

When a change can violate an invariant under concurrency, retries, configuration edits, malformed input, or unauthorized access, happy-path application checks are not sufficient.

Read `docs/flow-engine.md` for the model these invariants protect.

---

## 1. Tenancy and authorization

### INV-001 — Account isolation

An Account must never read, mutate, search, export, subscribe to, execute, or receive data/configuration belonging to another Account.

This applies to:

- Conversations/Customers;
- Agents/Teams;
- Flows/Stages/Rules/Blocks;
- Field Definitions/Values;
- Resources/Resource Types;
- Appointments;
- jobs/realtime/search/exports;
- integrations;
- AI/tool execution.

### INV-002 — Authorization is server-side

UI visibility does not grant authority. Every protected mutation must be authorized server-side.

### INV-003 — External payloads cannot choose tenant context

Inbound provider events resolve Account through trusted integration/channel configuration, never from an arbitrary tenant ID in the payload.

### INV-004 — Configuration references remain tenant-local

A Stage/Rule/Field/Resource selector configured in one Account cannot reference another Account's Agent, Team, Resource, Field, Flow, Stage, or other owned record.

---

## 2. Conversation and process truth

### INV-010 — Conversation is the lead/process instance

Reservi must not maintain a second canonical Lead/Opportunity/Deal record containing the same operational truth as Conversation.

### INV-011 — One authoritative current Stage

A Conversation participating in a Flow has one authoritative current Stage at a time.

History may record transitions but cannot compete with current truth.

### INV-012 — Stage is not merely a label

Progression is governed by the configured completion predicate for the current Stage, not by arbitrary UI status editing that bypasses required truth.

Administrative override, if ever supported, must be explicit, authorized, attributable, and semantically defined.

### INV-013 — Stage completion reads authoritative server state

A completion predicate evaluates against server-side authoritative Conversation/domain state. Ephemeral browser state, AI prose, or stale cached UI does not make a Stage complete.

### INV-014 — Stage advancement is race-safe and idempotent

Concurrent evaluators must not advance the same logical Stage twice, execute duplicate transition side effects, or leave current Stage/history contradictory.

### INV-015 — In-flight configuration semantics are deliberate

Changing active Flow/Stage configuration must not silently invalidate or reinterpret in-flight Conversations without defined semantics.

Versioning, constrained edits, or explicit migration must be used where needed.

### INV-016 — Internal Notes never become customer Messages

An internal Note must never be transported through a customer-facing channel accidentally.

---

## 3. Flow engine invariants

### INV-020 — One predicate model

Routing, assignment conditions, Stage completion, and other configurable conditional behavior should use one normalized predicate/expression model rather than conflicting condition engines.

### INV-021 — Rules do not bypass domain operations

A Rule Action must invoke the same authorized domain operation that a human/API/AI action would use.

Rules cannot directly mutate records in ways that bypass assignment history, Appointment conflict checks, Field validation, tenant scope, etc.

### INV-022 — Rule side effects are idempotent/protected

If a Rule predicate remains true across repeated evaluations, repeat evaluation must not repeatedly perform the same logical irreversible side effect such as sending the same Message or creating the same Appointment.

### INV-023 — Rule evaluation is bounded

Rule/action cascades must have explicit loop protection. A configuration cannot create unbounded recursion or infinite state mutation.

### INV-024 — Rule execution is explainable

For operationally significant automated changes, Reservi should be able to identify the Stage/Rule/condition/action that caused the change to the degree needed for debugging and user trust.

### INV-025 — User rules cannot execute arbitrary code

Account-configured predicates/actions use supported structured operators/capabilities. They do not execute arbitrary Ruby, JavaScript, SQL, shell, or provider payload expressions.

---

## 4. Field/state invariants

### INV-030 — Configurable values have explicit scope

A configurable Field's authoritative target is explicit: Customer/profile state or Conversation/request state (or another supported first-class target introduced deliberately).

Request-specific state must not silently contaminate durable Customer profile state.

### INV-031 — Field values conform to definitions

Every configured Field value validates against its current applicable type/options/constraints before becoming authoritative.

### INV-032 — AI-extracted Field values are not exempt

AI output is untrusted input and follows the same validation, tenant, authorization, and reference rules as human/API input.

### INV-033 — Stable configured references survive label changes

Rules/predicates must reference stable keys/IDs, not mutable display labels alone.

Renaming `Site visit` or `City` must not silently break or redirect existing logic.

### INV-034 — One source of truth per value

Projections/search indexes/caches may duplicate a value for performance, but exactly one authoritative writable source must be identifiable.

---

## 5. Appointment invariants

### INV-040 — Appointment is the canonical scheduling entity

Reservi must not maintain competing `Booking` and `Appointment` entities as separate scheduling truths.

`Booking` may be UI/action language; the durable scheduling record is Appointment.

### INV-041 — Appointment is not globally Service-bound

Appointment creation/confirmation/completion must not require a Service unless the relevant Account/Stage configuration explicitly requires Service state.

These configurations must remain representable:

- Appointment without Service;
- Service without Appointment;
- Appointment before Service selection;
- Service before Appointment;
- multiple Appointments;
- no Service concept.

### INV-042 — Multiple Appointment roles are unambiguous

When a Conversation has multiple Appointments, Stage predicates/actions must address the intended Appointment by stable role/key/reference rather than ambiguous `any appointment` semantics unless `any` is explicitly requested.

### INV-043 — Appointment time is unambiguous

Persisted appointment instants are stored consistently; timezone controls interpretation/display, not ambiguous local persistence.

### INV-044 — Exclusive participant/resource conflicts survive concurrency

If configured rules say an Agent/Resource cannot participate in overlapping committed Appointments, concurrent attempts must not both commit a conflict.

Use transaction/database protection appropriate to the selected model.

### INV-045 — Conversation and calendar show the same Appointment truth

Conversation UI, calendar UI, and Stage predicates must resolve to the same authoritative Appointment record/state.

### INV-046 — Appointment history/state is truthful

Reschedule/cancel/complete operations must preserve enough history/attribution to understand what happened where product operations require it.

---

## 6. Resource invariants

### INV-050 — Resource is independent from Appointment

A Resource may be selected/referenced without scheduling, and an Appointment may exist without a Resource.

Do not force a global Resource -> Appointment dependency in either direction.

### INV-051 — Resource types do not erase real domain concepts

Agent, Customer, Conversation, Appointment, Message, and other concepts with independent invariants must not be modeled as generic Resources merely for schema uniformity.

### INV-052 — Resource role references are unambiguous

When several Resource selections of the same/different types participate in one Conversation, configured roles/keys must identify the intended state reliably.

### INV-053 — Resource exclusivity is configured, not assumed

Not every Resource participates in scheduling conflicts. Exclusivity/availability semantics must be explicit for the Resource/Type/use case.

---

## 7. Assignment and Agent invariants

### INV-060 — One authoritative current owner

A Conversation normally has at most one authoritative current Agent owner at a time.

### INV-061 — Reassignment preserves history

Reassignment changes current ownership without destroying previous ownership/attribution.

### INV-062 — Rule/AI/manual assignment share the same authority

Whether assignment originates from a user, AI, or Rule, it must pass the same account/eligibility/authorization/invariant boundary.

### INV-063 — Human and AI actors obey the same domain constraints

An AI Agent cannot bypass a rule/permission simply because the request came from a prompt/tool call.

### INV-064 — Prompts do not grant capabilities

Runtime prompts can suggest an operation; server-side capability/authorization determines whether it can execute.

### INV-065 — Significant actions are attributable

Messages, assignments, Appointment mutations, Stage overrides/transitions, and other operationally important changes should be attributable to an Agent/system/rule execution where useful for reliable operations.

---

## 8. Messaging invariants

### INV-070 — Inbound duplicate delivery is safe

Duplicate provider delivery must not create duplicate customer Messages or duplicate downstream irreversible actions.

### INV-071 — Outbound retry does not casually duplicate Messages

Stable operation/provider identity or equivalent protection must prevent/reconcile duplicate sends whenever provider semantics allow.

### INV-072 — Rule-triggered Messages are execution-idempotent

Repeated Stage evaluation must not resend the same logical configured Message action simply because its predicate is still true.

### INV-073 — Provider state is not hidden process truth

Conversation Stage, Appointment, assignment, Resource selection, and Field state must not silently depend on provider-only state Reservi cannot reconcile.

---

## 9. Data integrity invariants

### INV-080 — Foreign relationships are valid

Durable ownership/association relationships use database foreign keys where practical.

### INV-081 — Race-sensitive uniqueness is database-enforced where possible

Model validation alone is insufficient for durable uniqueness/conflict truth under concurrency.

### INV-082 — Known durable truth is modeled explicitly

Do not hide stable/queryable domain truth entirely in unvalidated JSON solely to avoid schema design.

Validated structured configuration/AST JSON is acceptable where the shape is genuinely configurable.

### INV-083 — Historical records are not rewritten to fake the present

History describes what happened; current fields describe what is current.

---

## 10. Jobs and integrations

### INV-090 — Retryable jobs are idempotent/protected

Every retryable job is naturally idempotent or uses stable guards/operation identity.

### INV-091 — Local + remote operations are not assumed atomic

Database writes and provider calls are not one transaction. Model intermediate/reconciliation state where correctness requires it.

### INV-092 — Provider credentials never enter source control/normal logs

Secrets remain in runtime secret storage.

### INV-093 — Provider payloads normalize before domain predicates

Flow predicates/actions do not depend directly on arbitrary raw provider payload structure.

---

## 11. UI and mobile invariants

### INV-100 — Server truth survives refresh

Refreshing may change presentation but must restore the same authoritative process/domain truth.

### INV-101 — Stage progress is explainable

The UI should be able to show what requirements are satisfied/missing for the current Stage without inventing a second completion model.

### INV-102 — Core workflows are mobile-usable

Inbox, conversation, current Stage controls, Fields, assignment, Resource selection, and Appointment management remain usable on phone-sized screens.

### INV-103 — Realtime cannot leak Accounts

Turbo/WebSocket subscription identifiers and broadcasts maintain tenant isolation.

---

## 12. Simplicity and extensibility invariants

### INV-110 — No abstraction without present value

A new framework/layer solves a current need, not only imagined future scale.

### INV-111 — Future features integrate through the common contract

A new first-class feature should, where practical, integrate with Flow through:

```text
State + Controls + Predicates + Actions
```

rather than adding feature-specific transition code to the central Stage engine.

### INV-112 — No privileged service workflow

Core Flow/Appointment architecture must not regress to an assumption that Service is always selected, bookable, or required before scheduling.

### INV-113 — No universal metadata universe

Do not erase the domain into generic `Entity/Property/Relation/Node/Edge` structures merely to claim flexibility.

### INV-114 — Common paths remain traceable

An engineer/AI agent must be able to trace state mutation -> Flow evaluation -> Rule Actions -> Stage completion without navigating hidden callback chains or a distributed event maze.

---

## 13. Implementation checklist

For every meaningful feature/change ask:

1. Which invariants are touched?
2. Which State does this feature expose?
3. Does it need a Control, Predicate, or Action integration?
4. Can it be represented without modifying the central Flow engine?
5. Can retries execute an Action twice?
6. Can concurrent mutation advance a Stage twice?
7. Can active configuration changes invalidate in-flight state?
8. Can a cross-account reference be configured or submitted?
9. What DB constraint/transaction protects durable truth?
10. What test proves the invariant?

If a hard invariant genuinely changes, update this document and the related architecture/product context deliberately in the same change.
