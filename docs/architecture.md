# Reservi Architecture

## 1. Architectural objective

Reservi should remain a compact, legible Rails monolith whose flexibility comes from a small set of composable domain primitives rather than from a generic workflow framework.

The architectural target is:

- Conversation as the process root;
- account-configured ordered Stages;
- one shared predicate/evaluation model;
- actions invoking normal domain operations;
- first-class entities such as Appointment and Resource exposing state into the Stage engine;
- humans and AI operating against the same state;
- PostgreSQL as durable truth;
- Hotwire/server-rendered UI;
- explicit integration boundaries;
- safe concurrency/retries;
- local reasoning without internal-framework archaeology.

Read `docs/flow-engine.md` before changing workflow/state architecture.

---

## 2. System shape

```text
┌─────────────────────────────────────────────────────────┐
│                    Rails Monolith                       │
│                                                         │
│ HTTP / Turbo / Webhooks                                 │
│          │                                              │
│          ▼                                              │
│ Request boundaries / authorization                      │
│          │                                              │
│          ▼                                              │
│ Domain operations + models                              │
│          │                                              │
│          ├─────────────┐                                │
│          ▼             ▼                                │
│      PostgreSQL      Active Job                         │
│          │             │                                │
│          │             ▼                                │
│          │       Integration adapters                   │
│          │                                              │
│          ▼                                              │
│ Flow Runtime                                            │
│ Conversation -> Stage -> Rules -> Actions -> Completion │
│          │                                              │
│          ▼                                              │
│ Views + Turbo + Stimulus                                │
└─────────────────────────────────────────────────────────┘
```

The Flow Runtime is domain logic inside the monolith, not a separate service.

---

## 3. Preferred technology posture

Default stack:

- Ruby on Rails;
- PostgreSQL;
- Hotwire (Turbo + Stimulus);
- Active Job;
- Active Storage where appropriate;
- server-rendered authentication/authorization patterns;
- explicit provider adapters.

Add infrastructure such as Redis, dedicated search, extra realtime systems, or external analytics only when a measured need exists.

The repository/Gemfile becomes authoritative once bootstrapped.

---

## 4. Core architectural formulas

```text
Conversation = Authoritative State + Current Stage
```

```text
Stage = Blocks + Rules + Completion Predicate
```

```text
Rule = Predicate + Actions
```

```text
Feature integration = State + Controls + Predicates + Actions
```

The central Flow engine must stay ignorant of vertical-specific concepts where possible.

It should not contain code equivalent to:

```text
if salon -> require service before booking
if car rental -> require vehicle before booking
if real estate -> require property before viewing
```

Instead, account configuration expresses those requirements through supported state and predicates.

---

## 5. Boundary model

### HTTP boundary

Controllers handle authentication/account context, authorization, input parsing, invoking domain behavior, and choosing HTML/Turbo/JSON response.

Controllers do not own business rules.

### Domain boundary

Active Record models and focused operations own durable business truth.

Use explicit operations where orchestration genuinely spans multiple records or where a named operation protects important invariants.

Examples likely deserving focused operations:

- assign Conversation;
- apply configured Field value;
- create/reschedule/cancel Appointment;
- select/release Resource;
- evaluate current Stage;
- advance Stage safely;
- execute Rule action once.

Avoid service-object-per-controller-action architecture.

### Persistence boundary

PostgreSQL protects durable invariants and concurrency-sensitive uniqueness/conflict rules.

### Integration boundary

Provider-specific transport/payload/status behavior stays in adapters/jobs near the edge.

### UI boundary

Rails renders authoritative state. Turbo updates server-rendered fragments. Stimulus handles browser-local interaction, not domain truth.

---

## 6. Multi-tenancy

Account is the primary tenant boundary.

Every account-owned record/configuration must have an unambiguous ownership path, including:

- Flow / Stage / Rule / Block configuration;
- Field Definitions / Values;
- Resource Types / Resources;
- Appointments;
- Agents / Teams;
- Conversations / Customers;
- integrations.

A Rule configured in Account A must never reference Agent/Team/Resource/Field/etc. from Account B.

Jobs must re-scope server-side. Webhooks derive account from trusted integration identity. Turbo/realtime channels stay tenant-scoped.

---

## 7. Conversation as process root

Conversation is the aggregate-like operational center, but should not become a God object.

Conversation coordinates/references current process state while local entities own their own invariants.

Conceptually:

```text
Conversation
├── current Flow / Stage
├── Customer
├── Fields
├── owner / Team
├── Messages / Notes
├── Appointments
├── Resource selections
└── history
```

The Flow engine reads this normalized state graph.

Do not duplicate equivalent truth in Lead/Deal models.

---

## 8. Flow / Stage architecture

### Initial shape

Prefer an ordered Flow:

```text
Flow
  Stage 1
  Stage 2
  Stage 3
```

Conversation stores/references one authoritative current Stage.

Do not introduce arbitrary node graphs, loops, parallel branches, timers, or script nodes until product requirements prove they are necessary.

### Stage configuration

A Stage has conceptually:

- display identity/name/position;
- Blocks;
- Rules;
- completion expression;
- next Stage through ordered/configured progression;
- lifecycle/version metadata as needed.

### Completion

Completion is evaluated server-side against authoritative state.

Example:

```text
field.city exists
AND owner exists
AND appointment.site_visit.status == confirmed
```

Stage advancement must be race-safe and idempotent. Two concurrent evaluators must not produce duplicate transitions/actions.

### Configuration mutability

Active configuration can affect in-flight Conversations, so editing it is not harmless CRUD.

Before implementing the builder, choose explicit semantics for active Flow changes. Strong candidates:

1. immutable/versioned Flow definitions once activated; new Conversations use new version;
2. constrained edits where destructive changes are blocked while referenced;
3. deliberate migration of in-flight Conversations.

Do not allow silent deletion/reordering that leaves Conversations pointing to invalid or semantically changed state.

---

## 9. Predicate/expression architecture

Use one supported expression model for all configurable conditions.

Examples:

```text
field("city") == "Marrakech"
field("budget") > 5000
owner.exists
appointment("site_visit").status == confirmed
resource("vehicle").exists
```

The evaluator should operate on a normalized, typed state-access API rather than arbitrary SQL, Ruby, or provider payloads.

### Requirements

- deterministic;
- type-aware;
- safe to evaluate;
- tenant-scoped;
- explicit operator whitelist;
- stable references/keys;
- explainable result;
- no arbitrary user-supplied code.

Do not create separate routing, assignment, completion, and message condition languages.

A compact AST/structured JSON representation is acceptable if validated and hidden behind domain objects/value objects rather than spread throughout application code.

Example conceptual structure:

```json
{
  "all": [
    { "ref": "field:city", "op": "eq", "value": "Marrakech" },
    { "ref": "owner", "op": "exists" }
  ]
}
```

This is persistence/configuration shape, not permission to build a universal programming language.

---

## 10. Rule/action architecture

Rules react to relevant state changes in the current Stage.

```text
Predicate true
    ↓
Authorized Action(s)
```

Actions call normal domain operations. They do not write around them.

### Rule execution identity

Irreversible/repeat-sensitive actions require explicit once-per-logical-trigger semantics.

The implementation should be able to answer:

- which Rule evaluated;
- against which Conversation/Stage/configuration version;
- which predicate matched;
- which Action was attempted;
- whether it already executed for the same logical trigger;
- outcome/failure.

This may justify a small RuleExecution/ActionExecution record if needed for idempotency and explainability. Do not create event sourcing.

### Loop protection

An Action can change state that makes another Rule applicable, or potentially re-trigger itself.

The runtime therefore needs:

- bounded evaluation cycles;
- detection of no-op/repeated state;
- action idempotency identity;
- transaction/lock strategy around Stage advancement;
- explicit handling for cascading rules.

Never solve loops with arbitrary sleeps or hidden callback ordering.

---

## 11. Event/evaluation trigger architecture

Relevant durable state mutation should schedule or invoke Flow evaluation in a predictable way.

Possible sources:

- Field update;
- owner/team change;
- Appointment state change;
- Resource selection/release;
- message/customer response when predicates depend on it;
- future feature state changes.

Avoid scattering direct `advance_stage!` calls throughout controllers/models.

Prefer one explicit entry point such as conceptually:

```text
ConversationFlow.evaluate(conversation, cause: ...)
```

Exact naming is implementation-dependent.

Avoid broad Active Record callback chains that make execution order invisible. Domain operations may explicitly request evaluation after durable state changes.

---

## 12. Field architecture

Configurable Fields need definitions plus validated values.

At minimum, definition records should distinguish target scope:

- Customer;
- Conversation/request.

Do not add schema columns dynamically per account-defined field.

Do not collapse all known business state into arbitrary unvalidated JSON either.

A practical implementation may use typed value records or validated JSONB with a strong definition/evaluation layer. Choose based on query/index complexity and Rails ergonomics, but preserve:

- type validation;
- stable keys;
- account scope;
- referential safety for reference fields;
- efficient lookup for Stage evaluation;
- migration/version semantics when definitions change.

### Service

Service is optional reference/value state from the Flow engine's perspective.

A Service catalog may be a first-class feature when useful, but Appointment and Stage must not depend on Service globally.

---

## 13. Appointment architecture

`Appointment` replaces `Booking` as the canonical scheduling entity name.

Appointment is a time-bound commitment linked to Conversation, optionally involving Agents/Resources/location/reference state.

### Never assume Service dependency

Do not make `service_id` required by core Appointment schema/business logic.

A Service reference may be optional context if an account uses it.

### Stable logical roles

Multiple Appointments in one Conversation require role identity such as:

```text
site_visit
installation
follow_up
```

The role may come from a configured Appointment Block.

Completion predicates should address the intended role/reference explicitly.

### Conflict model

Availability is derived from the things actually constrained:

- participating Agent schedule;
- selected exclusive Resources;
- account/location hours/exception rules where implemented;
- existing committed Appointments;
- duration/buffers where configured.

A Service can provide defaults such as duration but cannot be the universal source of scheduling truth.

Concurrent conflicting commitments must be rejected by transaction/database strategy where possible.

---

## 14. Resource architecture

Use `ResourceType` + `Resource` for configurable account-owned assets/entities such as cars, properties, rooms, or equipment.

Resource must remain independent from Appointment.

Possible relationships:

```text
Conversation -> Resource selection(role)
Appointment  -> Resource reservation/participation(role)
```

A Resource type may expose type-specific attributes through controlled Field-like definitions or validated metadata as product needs evolve.

Do not turn Agent, Customer, Conversation, or Appointment into Resources solely for uniformity.

### Availability/exclusivity

Resources need not all be schedulable/exclusive.

Configuration can distinguish whether a Resource participates in time conflicts. Do not force scheduling semantics on a property merely because it is a Resource.

---

## 15. Assignment/routing architecture

Assignment is a normal domain operation with one authoritative current owner and truthful history.

Routing is not a separate engine. It is a common use of Rule + assignment/team Actions.

Example:

```text
IF field.city == Marrakech
THEN assign Ahmed
```

The Assignment operation owns eligibility, authorization, history, and concurrency safety.

Rules merely invoke it.

This keeps manual assignment, AI assignment, and deterministic assignment consistent.

---

## 16. Human/AI Agent architecture

The domain-level Agent represents an operational actor.

```text
Agent
├── human-backed
└── AI-backed
```

Both use the same Stage requirements and authorized Actions.

AI should query current Stage state/missing requirements rather than relying only on prose prompt instructions.

Prompts may explain how to behave; durable Flow configuration defines operational truth.

All AI tool calls are untrusted inputs to normal domain operations.

---

## 17. Messaging architecture

Inbound:

```text
provider webhook
-> verify
-> resolve integration/account
-> deduplicate
-> normalize
-> resolve Customer/Conversation
-> persist Message
-> update attention/state
-> explicitly trigger/enqueue relevant Flow/AI processing
-> return promptly
```

Outbound:

```text
Agent/Rule action requests send
-> authorize/capability check
-> create stable local operation/message
-> enqueue provider send
-> reconcile remote result
```

Rule-triggered Messages need idempotency so Stage reevaluation cannot send the same configured message repeatedly.

---

## 18. Transactions and side effects

General shape:

```text
authorize/validate
-> transactionally write local truth
-> commit
-> enqueue external side effect
-> reconcile result
```

Do not keep DB transactions open around slow external APIs.

Rule execution that includes external effects should persist enough local execution intent/identity to make retries safe.

Stage progression should depend on authoritative domain state, not on an unconfirmed external call pretending to be atomic.

---

## 19. Background jobs

Use jobs for external APIs, retries, expensive processing, AI inference, outbound messages, reconciliation, and other slow work.

Jobs must be:

- tenant-scoped;
- retry-safe;
- idempotent/protected;
- observable;
- explicit about stale configuration/state handling.

A job executing a Rule Action should re-check whether the action remains valid if required by semantics, but must not duplicate already-committed irreversible work.

---

## 20. Realtime / UI

Turbo broadcasts improve shared awareness but never define truth.

The conversation UI should render:

- current Stage;
- Stage completion progress/missing requirements;
- relevant Blocks;
- current owner/team;
- Messages/Notes;
- relevant Appointment/Resource state.

Refreshing must restore correct state from the server.

Mobile behavior is mandatory for core operations.

---

## 21. Explainability

Automation that changes customer handling must be inspectable.

The system should be able to explain, when useful:

```text
Stage advanced because:
- Name present
- City present
- Owner assigned
```

or:

```text
Ahmed assigned because:
Stage: Qualification
Rule: Marrakech requests
Condition: City = Marrakech
```

Explainability should arise from structured predicates/actions/execution records, not from attempting to reconstruct reasons from logs after the fact.

---

## 22. Search

Start with PostgreSQL. Search/projection systems are never authorization or domain truth.

Configurable Field search/indexing should be added for demonstrated operational needs rather than indexing every possible value blindly.

---

## 23. Security architecture

- server-side authorization;
- strict tenant scoping;
- safe authentication/session handling;
- validated predicate/action configuration;
- no arbitrary code in user Rules;
- provider credential protection;
- attachment validation;
- webhook verification;
- AI capability enforcement.

Treat Flow configuration as executable business configuration and authorize its editing accordingly.

---

## 24. Performance and scalability

Scale the monolith before splitting the domain.

Flow evaluation should avoid N+1/configuration query explosions. Likely techniques include:

- preload current Stage configuration;
- compile/cache validated predicate configuration as a projection, not truth;
- index stable keys/lookups;
- evaluate only on relevant state changes;
- enqueue slow Actions;
- prevent repeated no-op evaluations.

Do not introduce an event bus/microservices merely because Rules exist.

---

## 25. Suggested application organization

Do not scaffold directories without code that needs them. A likely shape over time:

```text
app/
  models/
  controllers/
  views/
  jobs/
  javascript/controllers/

  operations/          # only meaningful multi-record domain operations
  integrations/        # provider adapters

  # If flow behavior becomes substantial, one focused namespace is reasonable:
  flow/
    evaluator.rb
    predicate.rb
    state_reader.rb
```

Names are illustrative. Prefer a small explicit namespace over a generic internal framework.

---

## 26. Anti-pattern checklist

Challenge changes that introduce:

- `Booking` and `Appointment` as competing scheduling truths;
- required Service on Appointment globally;
- hard-coded `qualification -> service -> appointment` flow;
- separate routing/assignment/completion condition engines;
- arbitrary user Ruby/JavaScript in Rules;
- generic BPM graph engine before branching requirements;
- universal Entity/Property/Relation metadata model;
- Stage advancement hidden in scattered callbacks;
- repeated side effects because a Rule predicate remains true;
- mutable active Flow configuration with undefined in-flight semantics;
- provider payloads used directly in predicates;
- client-side Stage truth;
- cross-account references in configuration;
- abstractions justified only by hypothetical future industries.

---

## 27. Architectural decision test

Before accepting a new abstraction, ask:

1. What current requirement forces this?
2. Can existing State + Controls + Predicates + Actions express it?
3. What independent lifecycle/invariant does it own?
4. Does it introduce a second truth?
5. Does it keep Flow evaluation understandable?
6. Does it preserve human/AI symmetry?
7. Can configuration and runtime behavior be tested deterministically?
8. Can a new engineer trace it quickly?

If the answer is primarily future speculation, do not add it.
