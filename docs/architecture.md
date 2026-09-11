# Reservi Architecture

## 1. Architectural objective

Reservi should remain a compact, legible Rails monolith whose flexibility comes from a small set of composable domain primitives rather than from a generic workflow framework or vertical-specific model tree.

The architectural target is:

- Conversation as process root;
- account-configured ordered Stages;
- one shared predicate/evaluation model;
- Actions invoking normal domain operations;
- Fields for arbitrary facts;
- Catalog + Item for reusable selectable business objects;
- Appointment as independent scheduling state;
- humans and AI operating against the same authoritative state;
- PostgreSQL as durable truth;
- Hotwire/server-rendered UI;
- explicit integration boundaries;
- safe concurrency/retries.

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

## 3. Core formulas

```text
Conversation = Authoritative State + Current Stage
Stage = Blocks + Rules + Completion Predicate
Rule = Predicate + Actions
Feature integration = State + Controls + Predicates + Actions
```

The central engine must not contain vertical branches such as:

```text
if service_business ...
if car_rental ...
if property_business ...
```

Different industries should mostly differ through Catalogs, Items, Fields, Stages, and Rules.

---

## 4. Preferred technology posture

Default stack:

- Ruby on Rails;
- PostgreSQL;
- Hotwire (Turbo + Stimulus);
- Active Job;
- Active Storage where appropriate;
- Rails-native/server-rendered authentication and authorization patterns;
- explicit provider adapters.

Add Redis, dedicated search, extra realtime infrastructure, or analytics systems only when a measured need exists.

The repository/Gemfile becomes authoritative once bootstrapped.

---

## 5. Boundary model

### HTTP boundary

Controllers establish authentication/account context, authorize, parse input, invoke domain behavior, and render HTML/Turbo/JSON.

### Domain boundary

Active Record models and focused operations own business truth.

Likely meaningful operations include:

- assign Conversation;
- apply Field value;
- select/clear Catalog Item;
- create/reschedule/cancel Appointment;
- evaluate current Stage;
- advance Stage;
- execute Rule Action once.

Avoid one service object per controller action.

### Persistence boundary

PostgreSQL protects durable truth and race-sensitive invariants.

### Integration boundary

Provider-specific transport/payload/status behavior remains in adapters/jobs.

### UI boundary

Rails renders authoritative state. Turbo updates fragments. Stimulus owns browser-local behavior only.

---

## 6. Multi-tenancy

Account is the primary tenant boundary.

Every owned/configured record must have an unambiguous Account path, including:

- Flow / Stage / Rule / Block;
- Field Definitions / Values;
- Catalogs / Items / ItemSelections;
- Appointments;
- Agents / Teams;
- Conversations / Customers;
- integrations.

Configuration must reject cross-account references.

Jobs re-scope server-side. Webhooks derive Account from trusted integration identity. Realtime/search/export paths remain tenant-scoped.

---

## 7. Conversation as process root

Conversation coordinates current process state while supporting records own local invariants.

Conceptually:

```text
Conversation
├── current Flow / Stage
├── Customer
├── Fields
├── Catalog Item Selections
├── owner / Team
├── Messages / Notes
├── Appointments
└── history
```

The Flow engine reads this normalized state graph.

Do not duplicate it into Lead/Deal/Opportunity records.

---

## 8. Flow / Stage architecture

Start with ordered Stages, not an arbitrary graph.

A Stage contains:

- identity/name/position;
- Blocks;
- Rules;
- completion expression;
- lifecycle/version metadata as needed.

Completion evaluates server-side against authoritative state.

Stage advancement must be race-safe and idempotent.

### Configuration mutability

Active Flow edits can affect in-flight Conversations. Before implementing the builder, choose explicit semantics such as:

1. versioned definitions once activated;
2. constrained destructive edits while referenced;
3. explicit migration of in-flight Conversations.

Do not silently reinterpret active Conversations.

---

## 9. Predicate/expression architecture

Use one structured, type-aware expression model for configurable conditions.

Examples:

```text
field("city") == "Marrakech"
owner.exists
item_selection("vehicle").exists
item_selection("vehicle").attribute("transmission") == "automatic"
appointment("pickup").status == confirmed
```

Requirements:

- deterministic;
- safe;
- tenant-scoped;
- stable references/keys;
- explicit operator whitelist;
- explainable results;
- no arbitrary Ruby/JavaScript/SQL.

A compact validated AST/JSON representation is acceptable as persistence shape, but domain/value objects should hide it from ordinary application code.

---

## 10. Rule/action architecture

Rules are:

```text
Predicate true
    ↓
Authorized Action(s)
```

Actions call the same domain operations used by humans/AI/API.

Irreversible Actions need stable logical execution identity so repeated Stage evaluation cannot resend the same Message, recreate the same Appointment, or repeat an equivalent side effect.

The runtime should be able to explain which Stage/Rule/condition/action caused an automated change.

### Loop protection

Actions may change state and trigger more Rules. The engine needs:

- bounded evaluation cycles;
- no-op/repeat detection;
- Action idempotency;
- explicit Stage advancement locking/transaction semantics.

Avoid hidden callback chains.

---

## 11. Flow evaluation trigger

Relevant durable state mutation should invoke/enqueue one explicit Flow evaluation entry point.

Sources include:

- Field changes;
- Catalog Item selection/clearing;
- Appointment changes;
- owner/team changes;
- Message state when predicates depend on it;
- future feature state.

Avoid scattered direct `advance_stage!` calls.

Prefer explicit domain orchestration over broad Active Record callback webs.

---

## 12. Field architecture

Fields represent facts.

Definition distinguishes at least Customer vs Conversation/request scope.

Do not create dynamic DB columns per account-defined Field.

Do not hide all known truth in arbitrary JSON either.

The implementation may use typed value records or carefully validated JSONB depending on query/index ergonomics, while preserving:

- type validation;
- stable keys;
- Account scope;
- efficient Flow evaluation;
- controlled definition changes.

---

## 13. Catalog / Item architecture

### Catalog

Account-owned collection of Items.

Examples are only names/data:

```text
Services
Cars
Rooms
Properties
Treatments
Products
```

Core architecture does not create separate model subclasses or scheduling rules based on these names.

### Item

Common shape:

```text
Item
├── catalog_id
├── title
├── description
├── price
├── images
├── typed additional attributes
└── lifecycle state
```

Use Active Storage or equivalent for images when appropriate.

Additional Catalog-specific attributes need a controlled definition/value strategy rather than arbitrary unvalidated blobs if they participate in Rules/search.

### ItemSelection

Conversation state linking a configured selector key to one or more Items.

Conceptually:

```text
Conversation
  item_selection("vehicle") -> Range Rover Evoque
  item_selection("property") -> Villa Agdal
```

Selection does **not** imply reservation, scheduling, ownership, or bookability.

### No vertical type hierarchy

Avoid:

```text
Service < Item
Car < Item
Property < Item
Room < Item
```

unless a future concept genuinely owns distinct invariants that cannot be expressed by Catalog/Item/attributes.

Do not create those classes just to name business categories.

---

## 14. Appointment architecture

Appointment is the canonical scheduling entity and is independent from Catalog/Item semantics.

Definition:

> A time-bound commitment associated with a Conversation.

It may contain:

- Conversation;
- logical role/key;
- starts_at / ends_at;
- status;
- participating Agent(s) when useful;
- location/context as needed;
- attribution.

### No Item requirement

Do not require `item_id`, `service_id`, `resource_id`, or `bookable` Item semantics for Appointment existence.

A selected Item is already visible through Conversation context.

Example:

```text
Conversation:
  vehicle = Range Rover Evoque
  pickup Appointment = tomorrow 14:00
```

The Appointment UI can present the selected vehicle by reading Conversation state. It need not own the vehicle relationship to make the workflow understandable.

### Scheduling conflicts

Initially, protect conflicts for scheduling concepts the product actually defines, such as an Agent not being in two committed Appointments simultaneously if that rule is configured.

Do **not** automatically treat every selected Item as an exclusive scheduling resource.

If future inventory reservation/capacity becomes required, introduce an explicit scheduling/reservation concept then.

---

## 15. Assignment/routing architecture

Assignment is one domain operation with authoritative current owner + truthful history.

Routing is a use of Rule + assignment/team Action, not a second engine.

Examples:

```text
IF field.city == Marrakech
THEN assign Ahmed
```

```text
IF item_selection("requested_service").attribute("category") == "irrigation"
THEN assign Irrigation Team
```

Manual, AI, and Rule-driven assignment share the same boundary.

---

## 16. Human/AI architecture

Human-backed and AI-backed Agents operate on the same Conversation state and Stage requirements.

AI should read current Stage and missing requirements rather than depending only on prose prompts.

All AI actions pass normal domain capability/authorization checks.

Prompts do not define authoritative Flow state.

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
-> invoke/enqueue relevant Flow/AI processing
-> return promptly
```

Outbound:

```text
Agent/Rule Action requests send
-> authorize
-> persist stable local operation/message
-> enqueue provider send
-> reconcile result
```

Rule-triggered Messages need Action idempotency.

---

## 18. Transactions and side effects

Prefer:

```text
authorize/validate
-> transactionally write local truth
-> commit
-> enqueue external side effect
-> reconcile result
```

Do not keep database transactions open during slow external calls.

Stage progression depends on authoritative local state, not assumed remote atomicity.

---

## 19. Background jobs

Jobs handle external APIs, retries, expensive processing, AI inference, messaging, and reconciliation.

They must be:

- tenant-scoped;
- retry-safe;
- idempotent/protected;
- observable;
- explicit about stale Flow/configuration handling.

---

## 20. UI / realtime

Conversation UI should render:

- current Stage;
- completion progress/missing requirements;
- relevant Blocks;
- owner/team;
- Messages/Notes;
- selected Items;
- relevant Appointment state.

Appointment/calendar details should surface relevant selected Items from Conversation context when useful.

Turbo improves shared awareness but never owns domain truth.

Refresh restores correctness.

---

## 21. Explainability

Automation should be explainable from structured configuration/execution data.

Examples:

```text
Ahmed assigned because:
Stage: Qualification
Rule: Marrakech requests
Condition: City = Marrakech
```

```text
Stage blocked because:
Vehicle selection missing
Pickup Appointment not confirmed
```

---

## 22. Security architecture

- strict Account scoping;
- server-side authorization;
- validated Rule configuration;
- no arbitrary user code;
- provider credential protection;
- safe attachments;
- webhook verification;
- AI capability enforcement.

Treat Flow configuration as executable business configuration and protect its editing accordingly.

---

## 23. Performance and scalability

Scale the monolith before splitting the domain.

Flow evaluation should avoid N+1/configuration query explosions through measured techniques such as:

- preload current Stage configuration;
- cache compiled validated expressions as projections, never truth;
- index stable keys/lookups;
- evaluate only on relevant state changes;
- enqueue slow Actions;
- avoid repeated no-op evaluation.

Do not introduce an event bus or microservices merely because Rules exist.

---

## 24. Suggested application organization

Do not scaffold folders until code needs them. A plausible future shape:

```text
app/
  models/
  controllers/
  views/
  jobs/
  javascript/controllers/
  operations/
  integrations/
  flow/
    evaluator.rb
    predicate.rb
    state_reader.rb
```

Names are illustrative. Keep the namespace small and explicit.

---

## 25. Anti-pattern checklist

Challenge changes that introduce:

- Service/Car/Room/Property as separate workflow primitives when Catalog/Item is sufficient;
- Resource/ResourceType duplicating Catalog/Item semantics;
- required Item/Service on Appointment;
- global `bookable` flags to make Appointment workflows work;
- hard-coded `qualification -> service -> appointment` progression;
- separate routing/assignment/completion condition engines;
- arbitrary user code in Rules;
- generic BPM graph engine before branching requirements;
- universal Entity/Property/Relation metadata model;
- Stage advancement hidden in callbacks;
- repeated Rule side effects;
- undefined in-flight configuration semantics;
- provider payloads used directly in predicates;
- client-side Stage truth;
- cross-account configuration references.

---

## 26. Architectural decision test

Before adding an abstraction, ask:

1. What current requirement forces it?
2. Can a Field express it if it is just a fact?
3. Can Catalog/Item express it if it is a reusable selectable thing?
4. Can Appointment express it if it is time-bound scheduling state?
5. Can existing State + Controls + Predicates + Actions integrate it?
6. What independent invariant/lifecycle does the new concept own?
7. Does it preserve one source of truth?
8. Does it keep the common path traceable?

If the justification is mainly hypothetical future flexibility, do not add it.
