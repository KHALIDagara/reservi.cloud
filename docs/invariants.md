# Reservi Invariants

These are hard product and engineering truths. Features may evolve, but these constraints remain true unless a deliberate product/architecture decision explicitly changes them.

Read `docs/flow-engine.md` for the model these invariants protect.

---

## 1. Tenancy and authorization

### INV-001 — Account isolation

An Account must never read, mutate, search, export, subscribe to, execute, or receive data/configuration belonging to another Account.

This includes Conversations, Customers, Agents, Teams, Flows, Stages, Rules, Fields, Catalogs, Items, ItemSelections, Appointments, jobs, realtime, integrations, and AI/tool execution.

### INV-002 — Authorization is server-side

UI visibility does not grant authority. Every protected mutation is authorized server-side.

### INV-003 — External payloads cannot choose tenant context

Inbound provider events resolve Account through trusted integration/channel configuration, never an arbitrary tenant ID in the payload.

### INV-004 — Configuration references remain tenant-local

A Stage/Rule/Field/Catalog selector configured in Account A cannot reference Account B's Agent, Team, Catalog, Item, Field, Flow, Stage, or Appointment.

---

## 2. Conversation and Stage truth

### INV-010 — Conversation is the lead/process instance

Reservi must not maintain a second canonical Lead/Opportunity/Deal record containing the same operational truth as Conversation.

### INV-011 — One authoritative current Stage

A Conversation participating in a Flow has one authoritative current Stage.

### INV-012 — Stage is an executable contract, not a decorative label

Progression is governed by the configured completion predicate over authoritative state.

### INV-013 — Completion reads server truth

Browser state, AI prose, stale cache, or optimistic UI cannot independently make a Stage complete.

### INV-014 — Stage advancement is race-safe and idempotent

Concurrent evaluators must not advance the same logical Stage twice or produce duplicate transition side effects.

### INV-015 — In-flight configuration semantics are deliberate

Changing active Flow/Stage configuration must not silently reinterpret or invalidate in-flight Conversations without defined semantics.

### INV-016 — Internal Notes never become customer Messages

Internal Notes must never be transported through a customer-facing channel accidentally.

---

## 3. Flow engine invariants

### INV-020 — One predicate model

Stage completion, assignment/routing conditions, messaging Rules, and other configurable conditions should use one normalized expression model.

### INV-021 — Rules do not bypass domain operations

A Rule Action invokes the same protected domain operation a human/AI/API would use.

### INV-022 — Rule side effects are idempotent/protected

Repeated evaluation of a true predicate must not repeatedly perform the same logical irreversible Action.

### INV-023 — Rule evaluation is bounded

Rule/action cascades must have explicit loop protection.

### INV-024 — Rule execution is explainable

For meaningful automated changes, Reservi should be able to identify the Stage, Rule, matched condition, and Action that caused the change.

### INV-025 — User Rules cannot execute arbitrary code

Configured predicates/actions use supported structured operators/capabilities, not arbitrary Ruby, JavaScript, SQL, shell, or raw provider expressions.

---

## 4. Field invariants

### INV-030 — Configurable Fields have explicit scope

A Field's authoritative target is explicit, at minimum Customer/profile or Conversation/request.

### INV-031 — Field values conform to definitions

Values validate against type/options/constraints before becoming authoritative.

### INV-032 — AI-extracted values are not exempt

AI output follows the same validation, authorization, and Account rules as human/API input.

### INV-033 — Stable keys survive label changes

Rules/predicates reference stable keys/IDs rather than mutable display labels alone.

### INV-034 — One source of truth per value

Search indexes/caches/projections may duplicate a value, but one authoritative writable source must remain identifiable.

---

## 5. Catalog and Item invariants

### INV-040 — Catalog + Item is the common selectable business primitive

Services, cars, rooms, properties, treatments, packages, products, and similar reusable selectable business objects should not become separate Flow primitives when Catalog/Item expresses them cleanly.

### INV-041 — Item type/name does not grant hidden behavior

An Item does not become schedulable, reservable, or otherwise privileged merely because it lives in a Catalog named `Services`, `Cars`, `Rooms`, etc.

### INV-042 — No global `bookable` prerequisite

Core Appointment behavior must not require `item.bookable = true` or equivalent classification.

### INV-043 — ItemSelection means selection, not reservation

Selecting an Item into Conversation state does not inherently mean that the Item is booked, reserved, owned, exclusive, or scheduled.

### INV-044 — ItemSelection roles are unambiguous

Configured selector keys/roles identify which Item selection a predicate refers to when multiple selections exist.

### INV-045 — Item attributes are validated data, not subtype behavior

Catalog-specific additional attributes must follow their configured definitions/types when used in Rules/search/UI.

Do not introduce subtype classes merely because attributes differ.

### INV-046 — Item lifecycle changes do not silently corrupt in-flight state

Archiving/deleting/changing an Item referenced by active Conversations must have defined behavior. Historical/current selections must not become meaningless silently.

---

## 6. Appointment invariants

### INV-050 — Appointment is the canonical scheduling entity

Reservi must not maintain competing `Booking` and `Appointment` entities as separate scheduling truths.

`Booking` may be UI/action language; the durable entity is Appointment.

### INV-051 — Appointment is independent from Catalog Item selection

Appointment creation/confirmation/completion must not globally require a selected Item.

Likewise, selecting an Item must not require an Appointment.

These all remain valid:

```text
Appointment without Item selection
Item selection without Appointment
Appointment before Item selection
Item selection before Appointment
multiple Item selections
multiple Appointments
no Catalog at all
```

### INV-052 — Appointment does not infer Item bookability

The presence of an Appointment plus a selected Item does not require the system to infer or persist that the Item itself is `bookable`.

The business meaning can come from shared Conversation context and configured Stage order.

### INV-053 — Multiple Appointment roles are unambiguous

When several Appointments exist, predicates/actions identify the intended logical Appointment by stable role/key/reference.

### INV-054 — Appointment time is unambiguous

Persisted appointment instants use consistent timezone-safe semantics.

### INV-055 — Defined scheduling conflicts survive concurrency

If the product/configuration defines an Agent or other explicit scheduling participant as unable to overlap committed Appointments, concurrent attempts must not both commit an invalid conflict.

Do not automatically treat every selected Item as such a participant.

### INV-056 — Conversation and calendar show the same Appointment truth

Calendar and Conversation views resolve to the same authoritative Appointment state.

---

## 7. Assignment and Agent invariants

### INV-060 — One authoritative current owner

A Conversation normally has at most one authoritative current Agent owner at a time.

### INV-061 — Reassignment preserves history

Reassignment changes current ownership without erasing previous ownership/attribution.

### INV-062 — Manual, Rule, and AI assignment share the same boundary

All assignment origins pass the same tenant, eligibility, authorization, and concurrency rules.

### INV-063 — Human and AI actors obey the same domain constraints

AI cannot bypass domain invariants because the request came from a prompt/tool call.

### INV-064 — Prompts do not grant capabilities

Server-side capability/authorization determines whether an AI action can execute.

### INV-065 — Significant actions are attributable

Messages, assignments, Appointment mutations, Stage transitions/overrides, Item selections when operationally important, and other significant changes should be attributable enough for reliable operations.

---

## 8. Messaging invariants

### INV-070 — Inbound duplicate delivery is safe

Duplicate provider delivery must not create duplicate customer Messages or duplicate downstream irreversible Actions.

### INV-071 — Outbound retries do not casually duplicate Messages

Stable operation/provider identity or equivalent protection must prevent/reconcile duplicate sends whenever possible.

### INV-072 — Rule-triggered Messages are execution-idempotent

Repeated Stage evaluation must not resend the same logical configured Message Action simply because its predicate remains true.

### INV-073 — Provider state is not hidden process truth

Stage, Appointment, assignment, Field, and ItemSelection state must not silently depend on provider-only state Reservi cannot reconcile.

---

## 9. Data integrity invariants

### INV-080 — Foreign relationships are valid

Durable associations use database foreign keys where practical.

### INV-081 — Race-sensitive uniqueness is database-enforced where possible

Model validation alone is insufficient for durable uniqueness/conflict truth under concurrency.

### INV-082 — Known durable truth is modeled explicitly

Do not hide stable/queryable domain truth entirely in unvalidated JSON just to avoid schema design.

Validated structured configuration/AST data is acceptable where shape is genuinely configurable.

### INV-083 — Historical records are not rewritten to fake the present

History describes what happened; current fields/projections describe what is current.

---

## 10. Jobs and integrations

### INV-090 — Retryable jobs are idempotent/protected

Every retryable job is naturally idempotent or uses stable guards/operation identity.

### INV-091 — Local + remote operations are not assumed atomic

Database writes and provider calls are not one transaction. Model reconciliation/intermediate state where correctness requires it.

### INV-092 — Provider credentials never enter source control/normal logs

Secrets remain in runtime secret storage.

### INV-093 — Provider payloads normalize before domain predicates

Flow predicates/actions do not depend directly on arbitrary raw provider payload structure.

---

## 11. UI and mobile invariants

### INV-100 — Server truth survives refresh

Refreshing restores the same authoritative process/domain truth.

### INV-101 — Stage progress is explainable

The UI can show which completion requirements are satisfied/missing without inventing a second completion model.

### INV-102 — Appointment surfaces can derive relevant Item context from Conversation

An operator viewing an Appointment should be able to see relevant selected Items from the Conversation without requiring duplicate Appointment-specific Service/Resource fields.

### INV-103 — Core workflows are mobile-usable

Inbox, Conversation, Stage controls, Fields, Catalog selectors, assignment, and Appointment management remain usable on phone-sized screens.

### INV-104 — Realtime cannot leak Accounts

Realtime subscription/broadcast identifiers preserve tenant isolation.

---

## 12. Simplicity and extensibility invariants

### INV-110 — No abstraction without present value

A new framework/layer solves a current need, not imagined future scale.

### INV-111 — Future features integrate through the common contract

A new first-class feature should, where practical, integrate through:

```text
State + Controls + Predicates + Actions
```

rather than feature-specific transition code in the Stage engine.

### INV-112 — No privileged service workflow

Core Flow/Appointment architecture must never regress to an assumption that Service selection is mandatory or precedes scheduling.

### INV-113 — Prefer Catalog/Item before vertical object types

Before adding Service/Car/Room/Property/etc. models, prove that Catalog/Item + typed attributes cannot express the requirement without losing a real invariant.

### INV-114 — No universal metadata universe

Do not erase all domain concepts into generic Entity/Property/Relation/Node/Edge structures.

Catalog/Item is generic only for reusable selectable business objects.

### INV-115 — Common paths remain traceable

An engineer/AI agent should be able to trace state mutation -> Flow evaluation -> Rule Actions -> Stage completion without hidden callback chains or a distributed event maze.

---

## 13. Implementation checklist

For every meaningful change ask:

1. Which invariants are touched?
2. Is this a fact (Field), a reusable selectable thing (Catalog Item), or time-bound commitment (Appointment)?
3. Which State does the capability expose?
4. Which Controls/Predicates/Actions are needed?
5. Can repeated evaluation execute an Action twice?
6. Can concurrent mutation advance a Stage twice?
7. Can active configuration changes invalidate in-flight state?
8. Can a cross-account reference be configured/submitted?
9. Are we accidentally adding Item bookability semantics?
10. What database/transaction/test proves the durable truth?

## 14. Concrete build-contract invariants

### INV-120 — Published process meaning is immutable

A Conversation remains pinned to its published FlowVersion. Publication changes only which version new instances use; no implicit migration, stage rewind, or destructive reinterpretation of referenced field types.

### INV-121 — Attention and outcome are distinct

New customer activity can require attention without reopening a completed process. Appointment cancellation does not erase past stage transitions or imply service was delivered.

### INV-122 — Selected context is stable

Selection predicates read the audited selection snapshot, not mutable current Item attributes. Updating listing data cannot silently reroute an old request; refresh/reselection is explicit.

### INV-123 — Pending work survives enqueue failure

Local state changes, accepted webhooks, outbound intents and AI run lifecycle have durable recovery state. Losing a job wakeup cannot lose the work.

### INV-124 — Ambiguous delivery is not assumed failure

If a provider may have accepted a send, retries require deduplication/reconciliation or an explicit operator decision. Do not label the message unsent merely because the local request timed out.

### INV-125 — Shared facts invalidate active readers

Customer profile revision changes durably trigger reevaluation of affected active Conversations. Evaluators read a coherent Customer/Conversation snapshot and record observed revisions.

### INV-126 — Stale AI authority cannot execute new work

Before applying a tool action or claiming an unstarted AI send, current ownership, membership, capabilities and input revisions must still allow it. Already in-flight remote effects are reconciled, not falsely claimed to be recalled.

### INV-127 — Rule bundles have a durable identity and boundary

Each Rule executes at most once successfully per stage entry; its local actions, outbound intents and success guard commit atomically. Failure pauses automatic advancement visibly. Retry never repeats a successful bundle.

### INV-128 — Same-account membership is not universal visibility

Team scope, ownership and capabilities restrict reads and actions within an Account, including Customer context, media, search, realtime and AI snapshots.


## 15. Account setup and AI knowledge invariants

### INV-130 — Account administration does not imply platform access

Creating/administering many Accounts uses explicit Account memberships. Current tab/session UI cannot retarget a request into another Account or expand visibility.

### INV-131 — Invitation acceptance grants verified membership once

A valid invitation must match the authenticated verified email and current authority; retries cannot duplicate membership/Agent or revive revoked tokens. Reactivation uses newly granted access, not old privileges. At least one active Account administrator remains.

### INV-132 — AI and human share operational assignment identity

Conversation owner and Team membership use Agent for both kinds. Pending invited humans and draft/paused/ineligible AI cannot receive new work. AI does not become a scheduled human calendar participant through assignment.

### INV-133 — Knowledge access is enforced before retrieval

Only permitted published source revisions enter search results, prompts, previews, downloads or caches. A different Account's source or an ungranted restricted source remains inaccessible.

### INV-134 — Instructions and examples cannot override domain truth

Stage requirements and capabilities come from canonical server state. Instructions, documents, Q&A, scenarios and summaries cannot bypass validation, grant actions or directly advance a Stage.

### INV-135 — AI context publication and revocation invalidate stale work

AI configuration, guidance and source-access generations are checked alongside owner/input revisions before new actions and unclaimed sends. Failed extraction does not replace usable published knowledge; archive/revoke immediately removes its authority.


### INV-136 — One work interface serves both Agent kinds

Human and AI Agents use the same actor-scoped workspace state, stage explanation, published Knowledge/Guidance and domain operations. Equivalent permissions yield equivalent source eligibility and validation. Agent kind alone does not determine Knowledge access. Handoff does not transfer source grants or leak restricted derived notes/summaries.
