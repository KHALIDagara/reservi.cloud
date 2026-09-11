# Reservi Domain Model

## 1. Modeling philosophy

Reservi uses a small set of durable concepts that represent real operational work while allowing each account to configure how a customer request progresses.

Two rules dominate the model:

> A lead is the Conversation.

> A Conversation progresses because its current Stage declares what state must become true next.

Do not create parallel Lead / Opportunity / Deal records for the same customer request. Do not hard-code an industry-specific sequence such as qualification -> service -> appointment.

Flexibility comes from composing truthful primitives, not from turning every object into generic metadata.

Read `docs/flow-engine.md` before changing Flow, Stage, Field, Rule, Appointment, Resource, assignment, or related concepts.

---

## 2. Conceptual relationship map

```text
Account
├── Users / Memberships
├── Agents
│   ├── human-backed
│   └── AI-backed
├── Teams
├── Channels / Integrations
├── Customers
├── Field Definitions
├── Resource Types
│   └── Resources
├── Flows
│   └── Stages
│       ├── Blocks
│       ├── Rules
│       └── Completion expression
└── Conversations
    ├── Customer
    ├── current Stage
    ├── current Team / Agent
    ├── Field Values
    ├── Messages / Notes
    ├── Appointments
    ├── Resource selections
    └── Assignment / state history
```

This is conceptual. The final database schema may use support/join records where correctness requires them.

---

## 3. Account

The tenant/organization whose data and configuration are isolated from all others.

Account-scoped configuration includes, as applicable:

- Agents and Teams;
- Channels / Integrations;
- Customers;
- Flows and Stages;
- Field Definitions;
- Resource Types / Resources;
- Appointments;
- account settings and permissions.

Tenant isolation is a hard invariant.

---

## 4. User

An authenticated human identity.

A User is not automatically an Agent in every Account. Account membership and operational Agent identity should remain explicit enough to support multi-account use safely.

Do not model AI agents as Users merely to reuse authentication fields.

---

## 5. Agent

An operational actor capable of performing work.

Human and AI actors share the same conceptual `Agent` abstraction.

Capabilities may include:

- receive assignment;
- read Conversation context;
- reply to the customer;
- add Note;
- update allowed Fields;
- create/change Appointment;
- select/release Resource where permitted;
- execute allowed actions;
- hand off/reassign.

AI-specific runtime/model/instructions/tools belong to configuration/capabilities, not to parallel operational models.

---

## 6. Team

A group of Agents used for routing, eligibility, queueing, permissions, or organizational grouping.

A Team may be selected by a Rule action. Team is not a workflow node.

Examples:

- Sales;
- Marrakech;
- Plumbers;
- After-hours;
- Agency Client A operators.

---

## 7. Customer

The account-scoped person or organization interacting with the business.

Customer owns durable profile facts that are meaningful across Conversations, such as:

- name;
- phone;
- email;
- language/locale;
- stable profile information;
- normalized channel identities.

Request-specific facts should usually live on the Conversation instead of polluting Customer state.

Example: a landscaping surface value for one request is normally a Conversation field, not `Customer.surface`.

---

## 8. Channel / Integration

A configured external communication or service integration belonging to an Account.

Examples: WhatsApp, email, SMS, calendar provider, future messaging channels.

Provider-specific payload/transport behavior remains at the integration boundary. Domain models should use normalized concepts.

---

## 9. Conversation

The central operational record and process instance for a customer request.

A Conversation is the lead.

Conceptually it exposes authoritative state such as:

- Account;
- Customer;
- channel/context;
- current Flow / Stage;
- current Team;
- current Agent owner;
- customer/conversation field values;
- Messages;
- Notes;
- Appointments;
- Resource selections;
- Assignment history;
- relevant state/audit history.

The Conversation is the process root. Supporting entities such as Appointment and Resource own their own local state and invariants while contributing to Conversation-level progression.

Do not duplicate current stage, owner, appointment state, or other canonical facts in a second Lead/Deal structure.

---

## 10. Flow

An account-configured ordered customer/operational progression.

The initial product should model Flow as an ordered set of Stages, not an arbitrary graph language.

A Conversation follows a Flow and has one authoritative current Stage.

Flow exists because users need to configure operational progression. It must remain simpler than a generic BPM/workflow product.

Possible future branching is not a reason to introduce a graph engine now.

---

## 11. Stage

A Stage is an executable desired-state contract, not merely a status label.

Formula:

```text
Stage = Blocks + Rules + Completion Predicate
```

A Stage answers:

1. What work/capabilities should be exposed now?
2. What deterministic reactions should happen when relevant state changes?
3. What must be true before the Conversation can proceed?

Example:

```text
Stage: Qualification

Blocks:
  Name
  Phone
  City

Rule:
  IF City = Marrakech
  THEN assign Ahmed

Complete when:
  Name exists
  AND Phone exists
  AND City exists
  AND Owner exists
```

Another account may have Stage 1 containing only an Appointment. There is no mandatory ordering of qualification, service, resource selection, or appointment.

A Stage should preserve a stable identity even if its display name changes.

---

## 12. Stage Block

A Block is a configurable product-facing capability/control exposed inside a Stage.

Blocks may include:

- Field input;
- Appointment selector/editor;
- Resource selector;
- controlled Agent/Team selection;
- file/document input where introduced;
- other future feature controls.

A Block is not automatically its own database model. It is configuration describing how a feature capability appears/behaves in the Stage.

Stateful blocks need a stable logical key/role when multiple instances of the same feature can exist.

Example:

```text
Appointment block
label: Site visit
key: site_visit
```

and later:

```text
appointment("site_visit").status == completed
```

Keys should survive label changes.

---

## 13. Predicate / Expression

A Predicate asks a deterministic question about authoritative state.

Examples:

```text
field("city") == "Marrakech"
field("budget") > 5000
owner.exists
owner == Ahmed
appointment("site_visit").status == confirmed
resource("vehicle").exists
```

Reservi should have one shared predicate/evaluation model rather than separate condition languages for assignment, completion, routing, and messaging.

Predicates never bypass authorization or invent state; they read normalized server-side state.

---

## 14. Rule

A persisted configurable reaction within the Flow/Stage system.

Formula:

```text
Rule = Predicate + Actions
```

Example:

```text
IF field("city") == "Marrakech"
THEN assign_agent(Ahmed)
     send_message(template: "ahmed_intro")
```

Rules require explicit priority/order semantics and idempotency semantics.

A rule whose predicate remains true must not repeatedly execute an irreversible action on every evaluation.

Rule execution should be explainable in history/logging.

---

## 15. Action

An authorized operation invoked by a Rule, human, or AI.

Examples:

- assign Agent;
- assign Team;
- send Message;
- set/update Field;
- create/update/cancel Appointment;
- select/release Resource;
- add Note.

Rules call the same domain operations used elsewhere. A Rule is not a privileged back door around invariants.

Every Action must respect:

- Account scope;
- actor/capability rules;
- validations;
- transaction/concurrency requirements;
- idempotency/retry requirements.

---

## 16. Field Definition and Field Value

Account-configurable structured state.

Field Definition may contain:

- stable key;
- label;
- type;
- allowed options;
- validation constraints;
- target scope (`customer` or `conversation`);
- display/order metadata;
- AI editability/capability configuration where useful.

Useful initial field types:

- short/long text;
- number;
- boolean;
- single choice;
- multi choice;
- date/time where appropriate;
- location/address;
- reference to a supported catalog/entity where justified.

Field Values validate against definitions before becoming authoritative.

Do not dynamically add database columns for account-defined fields. Do not hide all known durable truth in one unvalidated JSON blob either.

### Service as field/reference state

Service selection is not privileged by the Flow engine.

An account may expose a Service catalog and a Field may reference an item from it. The selected Service is state that Rules and Predicates may inspect.

There is no invariant that every Conversation has a Service or that Appointment requires one.

---

## 17. Appointment

`Appointment` is the canonical durable scheduling entity.

The word `booking` may describe the action/UI of reserving time, but Appointment is the domain entity.

Definition:

> A time-bound commitment associated with a Conversation, optionally involving Agents, Resources, locations, or other context.

Expected state may include:

- Account;
- Conversation;
- Customer by relation/derivation where useful;
- logical role/key when created for a configured Stage block;
- starts_at;
- ends_at/duration;
- status;
- participants/Agents where relevant;
- Resources where relevant;
- notes/context;
- creator/actor attribution.

Candidate statuses may include `tentative`, `confirmed`, `completed`, `cancelled`, `no_show` as product use proves necessary.

### Critical rule

Appointment is **not service-bound by default**.

These must all remain valid configurations:

- Appointment without Service;
- Service without Appointment;
- Appointment before Service selection;
- Service selection before Appointment;
- multiple Appointments in one Conversation;
- no Service concept at all.

Do not introduce mandatory `service_id` coupling because it happens to fit salons or service businesses.

### Multiple appointments

A Conversation may contain distinct Appointments such as:

- site visit;
- installation;
- pickup;
- delivery;
- follow-up.

Flow predicates must identify the intended Appointment by stable role/key or explicit reference.

### Conflict rule

When an Agent/Resource cannot participate in overlapping confirmed Appointments, concurrency-safe database/domain rules must protect the constraint.

---

## 18. ResourceType and Resource

A generic account-owned concept for assets/entities that can be selected, assigned, scheduled, reserved, or referenced.

Examples of Resource Types:

- Car;
- Property;
- Room;
- Equipment;
- Chair;
- Machine;
- Boat;
- Rental unit.

A Resource may have:

- Account;
- ResourceType;
- name/label;
- active/archive state;
- type-specific validated attributes;
- availability/scheduling configuration where required.

Resources are independent from Appointments:

- a Resource can be selected in a Stage without scheduling it;
- an Appointment may involve zero, one, or multiple Resources.

Do not turn every domain object into Resource. Customer, Agent, Conversation, Appointment, Message, etc. remain explicit concepts because they own different invariants.

---

## 19. Resource Selection / Relation

A Conversation/Stage may need Resources in named roles.

Examples:

```text
resource("vehicle") = Range Rover Evoque
resource("property") = Villa Agdal
```

The exact schema may use a join record linking Conversation/Appointment/Resource with a role key.

Role identity must be stable enough for predicates and history.

If an Appointment reserves a Resource, the relation must participate in availability/conflict rules where the account has declared the Resource exclusive.

---

## 20. Assignment

Assignment provides current ownership plus truthful history.

Conversation has one authoritative current Agent owner under normal operation. Team may represent current queue/responsibility scope.

Historical Assignment records preserve:

- assigned Agent/Team;
- start/end/superseded times;
- actor/system source;
- reason/rule where useful.

Assignment is invoked through an Action just like manual assignment.

Example Stage Rule:

```text
IF city == Marrakech
THEN assign Ahmed
```

The Rule engine does not own assignment truth; the assignment domain operation does.

---

## 21. Message

A customer-visible inbound or outbound communication belonging to a Conversation.

Properties include normalized direction/content/attachments/provider identity/delivery state and sender attribution.

Inbound duplicate provider delivery must be idempotent. Outbound retries must not casually double-send.

An AI-generated/sent Message should still be attributable to the acting Agent/capability.

---

## 22. Internal Note

Internal collaboration content that must never be delivered through a customer-facing channel.

It may appear in a unified Conversation timeline but retains a distinct visibility invariant.

---

## 23. Service Catalog (optional feature)

An account may maintain a Service catalog when useful for product behavior such as:

- display name/description;
- default price/duration;
- service-specific metadata;
- reporting/filtering;
- availability defaults.

The presence of this catalog does not make Service mandatory in Flow or Appointment.

From the Flow engine's perspective a selected service is reference/value state exposed through a Field/Block.

Do not build core scheduling around the assumption that every Appointment books a Service.

---

## 24. Future feature integration contract

A future first-class feature should integrate into Flow by exposing some subset of:

```text
Feature = State + Controls + Predicates + Actions
```

Example Quote:

```text
State: quote.status, quote.total
Control: Quote Builder
Predicates: quote.exists, quote.status == accepted
Actions: create_quote, send_quote
```

Then Stage configuration can use the feature without adding quote-specific transition logic to the central Flow engine.

This is the preferred extension mechanism.

---

## 25. History and audit

Do not create a universal event-sourced `Activity` truth system by default.

Preserve domain-specific history where it matters:

- Messages;
- Notes;
- Assignments;
- Appointment changes;
- Stage transitions;
- Rule/action execution records where needed for idempotency/explainability;
- meaningful field changes where auditability requires it.

A unified timeline can project these records.

---

## 26. Concepts explicitly rejected as defaults

Do not introduce these merely for flexibility:

- Lead / Opportunity / Deal parallel to Conversation;
- mandatory Service on Appointment;
- Booking as a separate second scheduling truth;
- a separate routing condition language;
- a separate assignment condition language;
- separate AI workflow engine;
- arbitrary code/script expressions in user rules;
- generic workflow graph nodes/edges before real branching requirements;
- universal Entity/Property/Relation meta-schema.

---

## 27. Concept admission test

Before adding a model/table, answer:

1. What real-world concept does it represent?
2. Who owns it?
3. What is its lifecycle?
4. What durable truth does it own?
5. What invariant does it protect?
6. Can existing State/Field/Resource/Appointment/Action concepts express it cleanly?
7. Does it duplicate existing truth?
8. How is it authorized and tenant-scoped?
9. What happens when archived/deleted?
10. Can it integrate with Flow through State + Controls + Predicates + Actions rather than changing the core engine?

If these answers are weak, do not add the concept yet.
