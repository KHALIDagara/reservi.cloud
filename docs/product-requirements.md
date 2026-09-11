# Reservi Product Requirements

## 1. Purpose

Reservi is a mobile-first, conversation-centric CRM and operations system for businesses that turn customer conversations into real work.

Its job is not merely to collect leads or schedule services. Its job is to help a customer request progress through the business with minimal friction while keeping operational state truthful automatically.

The core product model is:

```text
Customer conversation
      ↓
Conversation state
      ↓
Current Stage
      ↓
Humans + AI + deterministic rules make required state true
      ↓
Stage completion
      ↓
Next Stage
```

The CRM should maintain itself as a side effect of useful work.

The system should feel like a shared inbox plus operational workspace, not like a traditional CRM that forces separate Lead, Opportunity, Activity, and Deal bookkeeping.

---

## 2. Product principles

### 2.1 The Conversation is the lead and process instance

A lead is not a separate record pointing to a Conversation.

The Conversation is the operational root for the customer request and exposes the state needed to understand and progress it:

- customer context;
- messages and notes;
- current Stage;
- fields/structured data;
- current owner/team;
- Appointments;
- selected Resources;
- assignment/history;
- AI/human operational context.

Do not duplicate this truth in a parallel CRM object model.

### 2.2 Stages are work contracts, not labels

A Stage is not merely `new`, `qualified`, `booked`, etc.

A Stage declares:

```text
Stage = Blocks + Rules + Completion Predicate
```

The Stage answers:

- what should the operator/AI be able to do now?;
- what deterministic reactions should happen when state changes?;
- what must become true before this request proceeds?

This lets each account configure its operational flow without Reservi hard-coding a specific industry process.

### 2.3 No privileged service → appointment sequence

Reservi must not assume:

```text
qualification -> service -> appointment
```

A business may configure:

```text
appointment -> qualification
```

or:

```text
resource selection -> appointment
```

or:

```text
qualification -> quote -> payment
```

or a one-stage flow.

Service selection is optional state. Appointment is independent scheduling state. Resources are optional assets/entities. The account defines which state matters and when.

### 2.4 Humans, AI, and rules operate on the same state

Humans and AI share the conceptual `Agent` abstraction.

Both should be able, subject to permissions, to inspect current Stage requirements and act on the same Conversation truth.

Deterministic Rules also act through the same authorized domain operations.

There must not be separate human, AI, and automation versions of the business process.

### 2.5 Flexible through composition, not unlimited programmability

Reservi should be configurable enough to support many industries while remaining understandable.

The primary composition primitives are:

- Fields;
- Appointments;
- Resources;
- Agent/Team assignment;
- Messages/Notes;
- Rules;
- Stage completion predicates;
- future first-class features that expose state/controls/predicates/actions.

Reservi is not intended to become a generic no-code database or arbitrary workflow programming platform.

### 2.6 Mobile first

Core work must remain fully usable on phone-sized screens:

- inbox triage;
- conversation reading/replying;
- completing Stage requirements;
- updating fields;
- assigning/handoff;
- selecting Resources;
- creating/updating Appointments;
- understanding why progression is blocked.

---

## 3. Core vocabulary

### Conversation

The customer request / process instance / lead.

### Flow

The account-configured ordered set of Stages used for a class of Conversations.

### Stage

The current desired-state contract: Blocks + Rules + Completion Predicate.

### Field

Configurable structured value stored on either Customer or Conversation/request scope.

### Appointment

A time-bound commitment associated with a Conversation. It may optionally involve Agents, Resources, locations, or other context. It does not require a Service.

### Resource

An account-owned asset/entity that may be selected, assigned, referenced, scheduled, or reserved, such as a car, property, room, chair, or machine.

### Rule

A deterministic `IF predicate THEN actions` reaction to Conversation state.

### Action

An authorized operation such as assign Agent, assign Team, send Message, update Field, create/change Appointment, or select/release Resource.

See `docs/flow-engine.md` and `docs/domain-model.md` for canonical details.

---

## 4. Target users

Reservi should support the same mental model across:

- individual service providers;
- salons/clinics/consultants;
- plumbers/landscapers/installers/field-service businesses;
- rental businesses with cars/equipment;
- property/real-estate/concierge operations;
- multi-location companies;
- agencies distributing customer requests across providers/teams;
- organizations where AI and humans collaborate operationally.

The architecture should not require one workflow engine per vertical.

---

## 5. Stage builder

### 5.1 Entry point

An account administrator should be able to open a configuration surface such as:

```text
Settings
└── Stages / Flow
```

A new account may receive a sensible default first Stage named `Qualification`, but every Stage's name and contents are configurable.

### 5.2 Stage editing

A Stage editor should make the product model understandable without exposing a programming language.

Conceptually:

```text
Stage: Qualification

Blocks
  Name                    Customer field
  Phone                   Customer field
  City                    Conversation/customer field

Rules
  IF City = Marrakech
  THEN Assign Ahmed
       Send message "Ahmed will handle your request."

Complete when
  Name exists
  AND Phone exists
  AND City exists
  AND Owner exists
```

Another Stage might be:

```text
Stage: Site Visit

Blocks
  Site Visit              Appointment

Complete when
  Site Visit is confirmed
```

Another account may place that Appointment in Stage 1.

### 5.3 Blocks

Initial useful Blocks may include:

**Fields**
- text;
- number;
- boolean;
- choice/multi-choice;
- date/time;
- location/address;
- supported reference fields.

**Operational capabilities**
- Appointment;
- Resource selector;
- Agent/Team selector where permissions allow;
- future domain capabilities as they become real product features.

**Communication/actions**
- send configured message as a Rule action;
- internal Note where useful.

Do not make every Action a visual block when a simpler Rule configuration communicates it better.

### 5.4 Completion visibility

The user handling a Conversation must understand what remains incomplete.

Example:

```text
Qualification — 3/4 complete

✓ Name
✓ Phone
✓ City
○ Owner must be assigned
```

This same state should be machine-readable to AI Agents.

---

## 6. Fields

### 6.1 Scope

A configurable Field must specify where its truth belongs.

**Customer field** — durable across requests, e.g. name, phone, language.

**Conversation field** — specific to the current request, e.g. budget, surface, requested service, urgency, property type.

The UI may simply call both `Fields`, but storage/semantics must remain explicit.

### 6.2 Service selection

A Service is not mandatory system state.

An account may have a service catalog and expose a Service reference/choice Field in any Stage.

The system must support all of:

- Appointment without Service;
- Service without Appointment;
- Appointment before Service selection;
- Service selection before Appointment;
- no Service concept at all.

Do not make Service a hidden prerequisite for scheduling.

---

## 7. Appointments

### 7.1 Product meaning

Appointment is the canonical scheduling entity.

A user may say they are "booking" something, but Reservi stores/manages an Appointment.

An Appointment is a time-bound commitment related to the Conversation.

Examples:

- phone consultation;
- site visit;
- treatment;
- vehicle pickup;
- property viewing;
- installation;
- delivery;
- follow-up.

### 7.2 Optional relationships

An Appointment may involve:

- zero or more relevant Agents/participants;
- zero or more Resources;
- a location;
- optional reference data such as selected Service;
- a configured logical role such as `site_visit` or `installation`.

Service must not be mandatory.

### 7.3 Multiple Appointments

One Conversation may contain multiple Appointments.

A Stage must be able to require a specific logical Appointment:

```text
Site Visit status = completed
```

without confusing it with an Installation or Follow-up Appointment.

### 7.4 Completion flexibility

An Appointment may be created/confirmed/completed in Stage 1, Stage 2, another Stage, or outside Stage completion entirely depending on account configuration.

There is no global product rule that scheduling happens at a fixed point.

---

## 8. Resources

### 8.1 Purpose

Accounts may define Resource Types and Resources for assets/entities that matter operationally.

Examples:

```text
Car
Property
Room
Equipment
Chair
Machine
Boat
Rental unit
```

### 8.2 Independent use

A Resource may be selected in a Stage without an Appointment.

Example:

```text
Stage: Choose vehicle
Block: Vehicle [Resource selector]
Complete when: Vehicle selected
```

### 8.3 Scheduled use

An Appointment may optionally reserve/associate Resources.

Example:

```text
Appointment: Property Viewing
Resource: Villa Agdal
Agent: Ahmed
```

If a Resource is exclusive for a time interval, Reservi must prevent conflicting committed Appointments according to configured scheduling rules.

---

## 9. Rules, routing, and assignment

### 9.1 One condition model

Do not create separate rule engines for:

- routing;
- assignment;
- Stage completion;
- messages.

Use one predicate/expression model against normalized Conversation state.

### 9.2 Assignment as action

Example:

```text
IF City = Marrakech
THEN Assign Ahmed
```

or:

```text
IF Property.Region = Marrakech
THEN Assign Marrakech Team
```

or:

```text
IF Language = French AND Budget > 5000
THEN Assign Sarah
     Send premium French intro message
```

The assignment domain still owns current-owner integrity/history. The Rule merely invokes it.

### 9.3 Stage gate is separate from actions

A Rule may assign Ahmed, while the Stage independently declares:

```text
Complete when:
City exists
AND Owner exists
```

This separation prevents side effects and progression logic from becoming tangled.

### 9.4 Explainability

Users must be able to understand why an automated action happened.

Example:

```text
Assigned to Ahmed
Reason: Stage "Qualification" / Rule "Marrakech requests"
Matched: City = Marrakech
```

---

## 10. Human and AI operation

### 10.1 Shared goal state

The Stage should tell both humans and AI what is missing.

Example:

```text
Current Stage: Qualification
Required:
✓ Name
✓ City
○ Confirmed Site Visit
```

A human sees the control. An AI can reason from the same state and, if permitted, ask the customer for missing information or invoke the relevant capability.

### 10.2 AI extraction

AI may extract configured Fields from conversation text only when allowed and all values still pass normal Field validation.

### 10.3 AI cannot define truth by prompt

Prompts/instructions do not replace Flow configuration, authorization, or domain validation.

The durable Stage/Rule/Conversation state is authoritative.

---

## 11. Messaging and inbox

Conversation remains the primary daily-work surface.

The inbox should make it easy to see:

- customer;
- current Stage;
- current owner/team;
- attention/unread status;
- useful configured state relevant to the operator;
- blocked/missing requirement where useful.

From the Conversation, an Agent should be able to:

- read/reply;
- update current Stage Fields;
- see missing completion requirements;
- manage assignment;
- use Appointment/Resource controls exposed by the current Stage;
- inspect history/context.

Do not force operators into disconnected CRM modules to complete ordinary flow work.

---

## 12. Flow runtime behavior

On relevant state change, Reservi should conceptually:

```text
persist authorized state change
        ↓
evaluate applicable current-Stage Rules
        ↓
execute newly applicable Actions safely
        ↓
re-read authoritative state
        ↓
evaluate Stage completion predicate
        ↓
if complete -> advance to next configured Stage
```

Requirements:

- deterministic evaluation;
- explicit Rule priority/order semantics;
- loop protection;
- idempotency for irreversible actions;
- race-safe Stage advancement;
- explainability/audit for meaningful automated actions;
- no client-side-only workflow truth.

Initial product should prefer ordered Stages rather than arbitrary graph branching.

---

## 13. Feature integration contract

A future first-class product feature should integrate into Stage flows by exposing:

```text
Feature = State + Controls + Predicates + Actions
```

For example, a future Quote feature could expose:

- state: quote.status, quote.total;
- control: Quote Builder;
- predicates: quote exists, quote accepted;
- actions: create/send quote.

Then a Stage can say:

```text
Complete when Quote status = accepted
```

without the central Flow engine gaining quote-specific workflow code.

This is the preferred extensibility mechanism.

---

## 14. Multi-tenancy and account configuration

Each Account owns its configuration and operational data, including as applicable:

- Flows/Stages;
- Field Definitions;
- Rules;
- Agents/Teams;
- Resource Types/Resources;
- Customers/Conversations;
- Appointments;
- Channels/Integrations.

One Account must never be able to reference another Account's Agent, Resource, Stage, Rule, Field, Appointment, Customer, or Conversation through configuration or runtime operations.

---

## 15. Reliability requirements

Critical operations must tolerate retries, duplicate delivery, stale UI, and concurrent actors.

Particular high-risk areas:

- duplicate messaging webhooks;
- Rule action retries;
- two Rules/users assigning concurrently;
- concurrent Stage completion/advancement;
- two users booking an exclusive Agent/Resource;
- Action executed once remotely but local response lost;
- configuration changed while Conversations are in-flight.

Durable invariants require database/transaction protection where appropriate.

---

## 16. Configuration evolution

Changes to Flow configuration must not silently corrupt in-flight Conversations.

The implementation must deliberately define semantics for cases such as:

- Stage renamed;
- Stage reordered;
- Stage archived/deleted;
- required Block removed;
- completion expression changed;
- Rule changed;
- Field Definition changed;
- Resource archived;
- Agent removed.

The simplest viable strategy may be versioned Flow/Stage configuration or constrained edits once active Conversations depend on configuration. Do not assume mutable configuration is harmless.

The exact strategy should be chosen before implementing the builder.

---

## 17. Deliberate non-goals

Unless a concrete requirement changes this, Reservi is not trying to become:

- Salesforce clone;
- BPMN engine;
- Zapier/n8n replacement;
- arbitrary graph workflow editor;
- general-purpose scripting runtime;
- Airtable-style universal entity database;
- event-sourced platform;
- microservice mesh;
- generic marketing automation suite.

Do not support arbitrary user-supplied Ruby/JavaScript expressions in Rules.

Flexibility must remain bounded by supported state, predicates, controls, and actions.

---

## 18. Product success criteria

Reservi is succeeding when:

- an account can model its real customer process without code;
- the same primitives support a salon, field-service business, rental company, property operation, and agency without separate workflow architecture;
- Service is optional rather than baked into scheduling;
- Appointment can appear wherever the business needs it;
- Resources can participate without spawning vertical-specific code;
- operators always know what a Conversation needs next;
- AI can understand the same Stage goal as a human;
- Rules are deterministic and explainable;
- CRM state becomes more accurate because normal work produces it;
- system complexity grows slower than product capability.

---

## 19. Feature acceptance template

Before implementing a feature, express it as:

```text
Actor:
Trigger:
Relevant Stage / Flow state:
Preconditions:
Expected user-visible result:
Persisted truth:
Predicates affected:
Actions / side effects:
Authorization:
Invariants affected:
Concurrency / retry behavior:
Configuration compatibility:
Test / verification plan:
```

For any new first-class domain capability, additionally answer:

```text
What State does it expose?
What Controls does it expose?
What Predicates can inspect it?
What Actions can manipulate it?
Can it integrate without changing the core Stage engine?
```
