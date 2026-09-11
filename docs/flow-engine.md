# Reservi Flow Engine

## 1. Why this document exists

This document defines the central product abstraction that makes Reservi flexible without turning it into a generic workflow/BPM/no-code platform.

The core insight is:

> A Conversation is the running operational process. A Stage declares what must become true next. Blocks expose ways for humans and AI to change state. Rules react to state. The stage advances when its completion predicate becomes true.

This replaces older assumptions that Reservi has a privileged sequence such as:

```text
qualification -> service selection -> booking
```

That sequence is only one possible configuration. It is not the architecture.

A business may configure:

```text
appointment -> qualification -> property selection
```

or:

```text
qualification -> appointment
```

or:

```text
vehicle selection -> documents -> payment
```

or even a single stage containing only an appointment.

The flow engine must not care what industry the account belongs to.

---

## 2. The fundamental model

### Conversation = process instance

The Conversation is the operational root and carries or relates to the state needed to progress the customer request.

Conceptually:

```text
Conversation
├── current Stage
├── Customer
├── current Team / Owner
├── Fields / structured values
├── Messages / Notes
├── Appointments[]
├── Resource selections[]
├── Assignment history
└── other feature state exposed by installed product capabilities
```

The Conversation does not need to physically contain every value as columns. This is the conceptual state graph that the flow engine can observe.

### Stage = desired-state contract

A Stage is not merely a CRM label or status.

A Stage declares:

```text
Stage
= UI Blocks
+ Rules
+ Completion Predicate
```

A useful mental model is:

> Stage = Work + Gate

The stage presents or enables the work that can make required state true, and its gate decides whether the Conversation can advance.

### Rule = predicate + actions

A Rule is:

```text
IF <predicate over conversation state>
THEN <one or more actions>
```

Example:

```text
IF city == "Marrakech"
THEN assign Ahmed
     send "Ahmed will take care of your request."
```

### Completion = predicate(state)

A stage is complete when its completion predicate evaluates to true against authoritative server-side state.

Example:

```text
name exists
AND city exists
AND owner == Ahmed
```

or:

```text
appointment("site_visit").status == confirmed
```

or:

```text
resource("vehicle") exists
AND field("documents_received") == true
```

The completion predicate must not be a separate hard-coded transition implementation per business type.

---

## 3. Four reusable primitives

The flow engine should reason in four primitives.

### 3.1 State

State is durable truth or derived authoritative truth that can be queried.

Examples:

- customer/contact fields;
- conversation/request fields;
- current owner/team;
- appointment status/time;
- selected resources;
- message/customer-response state;
- later: quote state, payment state, document-signature state.

### 3.2 Controls / blocks

Controls are UI/agent affordances that let a human or AI manipulate state.

Examples:

- text/number/choice/date/location field;
- appointment selector/editor;
- resource selector;
- agent/team selector when allowed;
- file/document input;
- message action;
- future quote/payment/document controls.

Blocks are product-facing composition units, not necessarily database models.

### 3.3 Predicates

Predicates ask questions about state.

Examples:

```text
field("city") == "Marrakech"
field("budget") > 5000
owner == Ahmed
appointment("site_visit").exists
appointment("site_visit").status == completed
resource("vehicle").exists
resource("property").region == "Marrakech"
```

The same predicate system should be reused for:

- stage completion;
- assignment rules;
- message rules;
- routing/team actions;
- visibility/eligibility rules where justified.

Do not build separate condition languages for each feature.

### 3.4 Actions

Actions mutate domain state or schedule an explicit side effect through authorized domain operations.

Examples:

- assign Agent;
- assign Team;
- send Message;
- set/update Field;
- create/update/cancel Appointment;
- attach/select/release Resource;
- add internal Note;
- later: create/send Quote, request Payment, notify someone.

Every action must pass normal tenant, authorization, validation, idempotency, and domain-invariant checks. A rule never bypasses domain authority.

---

## 4. Stage builder UX

The account owner should be able to open **Stages** and configure an ordered operational flow.

A default account may begin with a Stage named `Qualification`, but the name and contents are configurable.

Example:

```text
Stage 1 — Qualification

Blocks
  Name                  [customer field]
  Phone                 [customer field]
  City                  [conversation/customer field as configured]

Rules
  IF City = Marrakech
  THEN assign Ahmed
       send "Ahmed will handle your request."

Complete when
  Name exists
  AND Phone exists
  AND City exists
  AND Owner exists
```

Stage 2 could be:

```text
Stage 2 — Request Details

Blocks
  Service               [reference/choice field]
  Surface               [conversation field]
  Property              [resource selector]

Rules
  IF Service = Irrigation
  THEN assign Irrigation Team

Complete when
  Service exists
  AND Property exists
```

Stage 3 could be:

```text
Stage 3 — Site Visit

Blocks
  Site Visit             [appointment]

Complete when
  appointment("site_visit").status = confirmed
```

But all of these arrangements are optional. `Site Visit` may be Stage 1. A Service field may not exist. A flow may not use Appointments at all.

---

## 5. Appointment is independent state

`Appointment` is the canonical scheduling entity.

The word **booking** may describe the user action of creating/reserving an Appointment, but the durable entity is Appointment.

An Appointment is:

> A time-bound commitment associated with a Conversation, optionally involving Agents, Resources, locations, or other context.

It is not inherently a booking of a Service.

A valid Appointment may exist with:

- no Service selected;
- no Resource selected;
- one or more Resources;
- one or more relevant Agents/participants;
- a purpose such as site visit, consultation, pickup, delivery, installation, follow-up, or another account-defined meaning.

Examples:

```text
Phone consultation
10:30–11:00
(no Service, no Resource)
```

```text
Vehicle pickup
14:00–14:30
Resource: Car #17
```

```text
Property visit
16:00–17:00
Resource: Villa Agdal
Agent: Ahmed
```

```text
Treatment appointment
09:00–10:00
Resource: Treatment Room 2
Agent: Sarah
```

A Conversation may have multiple Appointments with independent states.

Therefore Stage predicates must be able to refer to a specific logical appointment role/key rather than merely ask whether any Appointment exists.

Example:

```text
appointment("site_visit").status == completed
appointment("installation").status == confirmed
```

The Appointment contributes state to the Conversation's process; it does not become the process root or the sole holder of Conversation state.

---

## 6. Service is not privileged by the flow engine

There is no invariant that says an Appointment requires a Service.

There is no invariant that says Service selection must happen before Appointment creation.

There is no invariant that says every account must define Services.

A business may expose a service catalog because services can be useful first-class catalog data such as name, price, default duration, description, or eligibility. But in the flow engine a selected Service is simply reference/value state that predicates and actions can use.

Examples that must all remain legal:

```text
Appointment without Service      YES
Service without Appointment      YES
Appointment before Service       YES
Service before Appointment       YES
Multiple Appointments            YES
No Service concept at all        YES
```

Do not encode a mandatory `service_id` on Appointment merely because many service businesses use one. If a relationship is later useful, it must remain optional unless a specific account configuration/predicate requires it.

---

## 7. Fields and data scope

Not every configurable value belongs to the Customer.

Reservi should distinguish at least:

### Customer/contact field

Durable information about the person/business across conversations.

Examples:

- name;
- phone;
- email;
- language;
- stable address when appropriate.

### Conversation/request field

Information specific to this request/conversation.

Examples:

- surface area;
- urgency;
- budget;
- requested service;
- property type;
- problem description.

The stage builder may present both simply as `Field`, while configuration controls where the authoritative value lives.

Example:

```text
Label: Surface
Type: Number
Save on:
  ( ) Customer profile
  (x) This conversation/request
```

Do not create database columns dynamically for account-defined fields. Use validated definitions and values with appropriate indexing/projection strategies for frequently queried state.

---

## 8. Resources

Reservi needs a generic `ResourceType` / `Resource` concept for account-owned assets or entities that may be selected, assigned, scheduled, reserved, or referenced.

Examples of Resource Types:

- Car;
- Property;
- Room;
- Equipment;
- Chair;
- Machine;
- Boat;
- Rental unit.

Examples:

```text
ResourceType: Car
Resources:
  Mercedes A200
  Dacia Duster
  Range Rover Evoque
```

```text
ResourceType: Property
Resources:
  Villa Agdal
  Riad Medina
  Apartment Gueliz
```

A Resource can be selected in a Stage without any Appointment.

An Appointment can optionally involve one or more Resources when scheduling/availability requires it.

Do not create separate flow engines for cars, properties, rooms, or equipment. They are Resource state exposed to the same Stage/Rule engine.

Do not over-generalize every domain concept into Resource. Agents, Customers, Conversations, Appointments, Messages, etc. remain explicit concepts with their own invariants.

---

## 9. Stable block/role keys

A Conversation may contain multiple values/entities of the same feature type.

Therefore stateful Stage blocks need stable logical keys/roles.

Example:

```text
Appointment block
Label: Site visit
Key: site_visit
```

Later:

```text
Appointment block
Label: Installation
Key: installation
```

Predicates then remain unambiguous:

```text
appointment("site_visit").status == completed
appointment("installation").status == confirmed
```

Resources need the same concept when multiple selections serve different roles:

```text
resource("vehicle")
resource("pickup_property")
```

The user should primarily see human labels. Stable keys are system identity and may be hidden/generated unless advanced configuration requires them.

Keys must remain stable across label changes.

---

## 10. Assignment and routing are actions over the same state

Do not build a separate conceptual routing language and a separate assignment language.

Example:

```text
IF field("city") == "Marrakech"
THEN assign_agent(Ahmed)
```

Another rule may say:

```text
IF resource("property").region == "Marrakech"
THEN assign_team(Marrakech Team)
```

Another:

```text
IF field("language") == "French"
AND field("budget") > 5000
THEN assign_agent(Sarah)
     send_message(template: "premium_fr_intro")
```

The assignment domain still owns the invariant of one authoritative current owner. Rules merely invoke the assignment operation.

Stage completion can independently require assignment state:

```text
field("city").exists
AND owner.exists
```

This separation matters: actions make state change; completion predicates decide whether enough state is true to advance.

---

## 11. Runtime semantics

A relevant state change triggers evaluation of the current Stage.

Conceptually:

```text
STATE CHANGED
      ↓
Evaluate current-stage rules
      ↓
Execute newly applicable authorized actions
      ↓
Re-read authoritative state
      ↓
Evaluate completion predicate
      ↓
Complete?
  ├─ no  -> remain in Stage
  └─ yes -> advance to configured next Stage
             ↓
          evaluate new Stage as needed
```

Relevant state changes include:

- field value changed;
- Appointment created/updated/cancelled/completed;
- Resource selected/released;
- owner/team changed;
- message received/sent where a predicate depends on it;
- another feature state change exposed to the flow engine.

### Required safety properties

Evaluation must be:

- deterministic for the same authoritative state/configuration;
- tenant-scoped;
- authorized through domain actions;
- safe under duplicate events/retries;
- protected from infinite rule/action loops;
- race-aware when two changes happen concurrently;
- observable/explainable enough to diagnose why an action or transition occurred.

Rules should not repeatedly execute the same irreversible action simply because the predicate remains true. The implementation needs an explicit action/evaluation idempotency strategy.

---

## 12. Explainability

Automated behavior must be understandable to operators.

Assignment/history should be able to explain something like:

```text
Assigned to Ahmed

Why:
Stage: Qualification
Rule: Marrakech requests
Condition matched: City = Marrakech
Action: Assign Ahmed
```

Stage UI should be able to explain why progression is blocked:

```text
Qualification — 3/4 complete

✓ Name
✓ Phone
✓ City
○ Owner must be assigned
```

This is not only UX polish. It is an operational requirement for trustworthy automation and AI collaboration.

---

## 13. AI and human symmetry

The Stage is the shared operational contract for both humans and AI.

If the current Stage requires:

```text
Name
City
Appointment("site_visit").confirmed
```

then both a human and an AI should be able to determine what is missing through the same authoritative state.

Example inbound message:

```text
"Salam ana Khalid mn Marrakech, bghit nحدد visite l-jardin."
```

AI may extract/update allowed fields:

```text
name = Khalid
city = Marrakech
```

A Stage rule can assign Ahmed.

The same Stage can then expose the remaining goal:

```text
Missing: confirmed site_visit Appointment
```

The AI may ask for scheduling information or invoke the Appointment capability if permitted.

Do not encode the business flow only inside an AI prompt. The durable Flow/Stage configuration is the shared source of operational intent.

Prompts help the AI reason about the flow; prompts do not define authoritative flow state.

---

## 14. Feature integration contract

A future Reservi feature integrates cleanly with flows by exposing some subset of:

```text
Feature
= State
+ Controls
+ Predicates
+ Actions
```

Example: Quote

```text
State:
  quote.status
  quote.total

Control:
  Quote Builder

Predicates:
  quote.exists
  quote.status == accepted
  quote.total > 5000

Actions:
  create_quote
  send_quote
```

Then a Stage may declare:

```text
Complete when quote("proposal").status == accepted
```

The central Stage engine should not need quote-specific transition logic.

The same principle can later support Payment, Documents, Tasks, Deliveries, etc. only when those become real product features.

---

## 15. Boundaries: flexible, not infinitely generic

Reservi is **not** trying to become n8n, Zapier, Airtable, Salesforce Flow, or a general programming environment.

Avoid a universal meta-schema such as:

```text
EntityDefinition
Entity
PropertyDefinition
RelationDefinition
UniversalNode
UniversalEdge
```

Keep genuine domain concepts explicit:

```text
Conversation
Customer
Agent
Team
Appointment
Resource / ResourceType
FieldDefinition / FieldValue
Flow
Stage
Rule
Message
```

and add new first-class concepts only when they own meaningful lifecycle/invariants.

Flexibility should come from **composition of a small set of truthful primitives**, not from erasing the domain into metadata.

---

## 16. Initial scope constraints

The first implementation should prefer an ordered Stage flow rather than an arbitrary graph editor.

Suggested initial semantics:

- Flow has ordered Stages;
- Conversation has one current Stage;
- each Stage has Blocks;
- each Stage has Rules;
- each Stage has one completion expression composed from predicates;
- first matching/each applicable rule behavior must be explicitly defined by rule type, priority, and idempotency semantics;
- completing a Stage advances to the configured next Stage;
- terminal Stage completes/closes the flow according to explicit configuration.

Branching, loops, cross-flow jumps, timers, parallel stages, generic webhooks, scripting, and arbitrary code expressions should **not** be introduced until real product requirements justify them.

This preserves the useful 80% while keeping the engine inspectable.

---

## 17. Formula to preserve

For agents and engineers, remember these formulas:

```text
Conversation = State + Current Stage
```

```text
Stage = Blocks + Rules + Completion Predicate
```

```text
Rule = Predicate + Actions
```

```text
Completion = Predicate(Authoritative Conversation State)
```

```text
Feature integration = State + Controls + Predicates + Actions
```

And the product-level sentence:

> A Stage declares what must become true before the Conversation may proceed, and Reservi gives humans, AI, and deterministic rules the capabilities required to make that state true.
