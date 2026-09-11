# Reservi Product Requirements

## 1. Purpose

Reservi is a mobile-first, conversation-centric CRM and operations system for businesses that turn customer conversations into real work.

Its job is to help a customer request progress through the business with minimal friction while keeping operational state truthful automatically.

The core model is:

```text
Customer conversation
      ↓
Conversation state
      ↓
Current Stage
      ↓
Humans + AI + deterministic Rules make required state true
      ↓
Stage completion
      ↓
Next Stage
```

Reservi should feel like a shared inbox plus operational workspace, not a traditional CRM with separate Lead, Opportunity, Activity, and Deal bookkeeping.

The CRM should maintain itself as a side effect of useful work.

---

## 2. Product principles

### 2.1 Conversation is the lead and process instance

A lead is not a separate record pointing to a Conversation.

Conversation is the operational root for a customer request and exposes the state required to understand and progress it:

- customer context;
- messages and notes;
- current Stage;
- configured Field values;
- selected Catalog Items;
- current owner/team;
- Appointments;
- history/audit context.

### 2.2 Stages are work contracts, not labels

A Stage is not merely `new`, `qualified`, `booked`, etc.

```text
Stage = Blocks + Rules + Completion Predicate
```

A Stage declares what controls/capabilities are available now, what deterministic reactions may happen, and what must become true before progression.

### 2.3 No privileged business sequence

Reservi must not assume:

```text
qualification -> service -> appointment
```

Valid configurations include:

```text
appointment -> qualification -> catalog selection
catalog selection -> assignment -> appointment
qualification -> appointment
catalog selection only
appointment only
```

The account defines what matters and when.

### 2.4 Catalog + Item is the universal selectable business primitive

Reservi should not have separate workflow primitives for Services, Cars, Rooms, Properties, Treatments, Equipment, etc.

A business creates Catalogs such as:

```text
Services
Cars
Rooms
Properties
Treatments
Packages
Products
```

Each Catalog contains Items with a common shape:

- title;
- images;
- description;
- price;
- additional typed attributes;
- active/archive state.

The same Catalog Selector Block can therefore select a service, car, property, room, product, or any other reusable business Item.

### 2.5 Appointment is independent scheduling state

Appointment is a time-bound commitment associated with a Conversation.

Reservi must not require an Item or Service to create an Appointment.

Reservi must not require an Item to declare itself `bookable`.

A selected Item and an Appointment coexist as independent Conversation state. Their business meaning comes from the configured Flow and shared Conversation context.

### 2.6 Humans, AI, and Rules operate on the same state

Human Agents, AI Agents, and deterministic Rules must act on the same authoritative Conversation state and use the same protected domain operations.

Do not create parallel workflows for human work, AI work, and automation.

### 2.7 Flexible through composition, not unlimited programmability

Reservi should support many industries through a small set of primitives:

- Fields;
- Catalogs / Items / Item selections;
- Appointments;
- assignment/team state;
- Messages / Notes;
- Rules;
- Stage completion predicates;
- future first-class features that expose State + Controls + Predicates + Actions.

Reservi is not a general no-code programming platform.

### 2.8 Mobile first

Core operation must remain usable on phones:

- inbox;
- conversation;
- current Stage requirements;
- Field editing;
- Catalog Item selection;
- assignment/handoff;
- Appointment creation/update;
- understanding why progression is blocked.

---

## 3. Core vocabulary

### Conversation

The customer request, lead, and running process instance.

### Flow

The account-configured ordered set of Stages.

### Stage

The current desired-state contract: Blocks + Rules + Completion Predicate.

### Field

Configurable structured fact stored on Customer or Conversation/request scope.

### Catalog

An account-owned collection of reusable selectable business Items.

### Item

A reusable entity inside a Catalog with title, images, description, price, typed attributes, and lifecycle state.

### Item Selection

One or more Items selected into the Conversation through a configured Catalog Selector Block.

### Appointment

A time-bound commitment associated with the Conversation. It is independent from Item selection.

### Rule

`IF predicate THEN action(s)` over normalized Conversation state.

### Action

An authorized operation such as assignment, sending a Message, updating a Field, selecting an Item, or managing an Appointment.

See `docs/flow-engine.md` and `docs/domain-model.md` for canonical details.

---

## 4. Target users

The same model should support:

- individual service providers;
- salons/clinics/consultants;
- plumbers/landscapers/installers;
- rental businesses;
- property/real-estate/concierge operations;
- multi-location companies;
- agencies distributing requests across teams/providers;
- organizations where AI and humans collaborate.

A new vertical should usually be modeled by different Catalogs, Fields, Stages, and Rules—not by a new workflow architecture.

---

## 5. Stage builder

### 5.1 Entry point

An administrator can configure the operational Flow through a surface such as:

```text
Settings
└── Stages / Flow
```

A new Account may begin with a sensible Stage named `Qualification`, but the name and contents are configurable.

### 5.2 Stage editing

Example:

```text
Stage: Qualification

Blocks
  Name                    Customer field
  Phone                   Customer field
  City                    Conversation field

Rules
  IF City = Marrakech
  THEN Assign Ahmed
       Send "Ahmed will handle your request."

Complete when
  Name exists
  AND Phone exists
  AND City exists
  AND Owner exists
```

Another Stage:

```text
Stage: Choose Vehicle

Block
  Vehicle                 Catalog Selector -> Cars

Complete when
  Vehicle selected
```

Another:

```text
Stage: Pickup

Block
  Pickup                  Appointment

Complete when
  Pickup Appointment is confirmed
```

The same Account may place Pickup before Vehicle selection if that is its process.

### 5.3 Initial Block vocabulary

**Fields**
- text;
- number;
- boolean;
- choice/multi-choice;
- date/time;
- location/address.

**Catalog**
- Catalog Item Selector, single or multiple.

**Operational**
- Appointment selector/editor;
- Agent/Team selector where permissions allow.

Future domain features should add Blocks only when they own meaningful state/capability.

### 5.4 Completion visibility

Operators must understand what remains incomplete.

```text
Qualification — 3/4 complete

✓ Name
✓ Phone
✓ City
○ Owner must be assigned
```

AI Agents should be able to read the same missing requirements from authoritative state.

---

## 6. Fields

### Customer field

Durable profile facts across Conversations, such as name, phone, email, language.

### Conversation field

Facts specific to the request, such as budget, surface, urgency, issue description.

The Stage builder may present both as `Field`, but target scope is explicit.

Fields are for facts. Catalog Items are for reusable selectable entities that deserve their own listing/card.

Useful heuristic:

> If it is a fact about this Customer/request, use a Field. If it is a reusable thing the business presents and selects, use a Catalog Item.

---

## 7. Catalogs and Items

### 7.1 Catalog creation

An Account can create Catalogs such as:

```text
Services
Cars
Rooms
Properties
Treatments
Packages
Products
```

No special system behavior is attached merely because a Catalog is named `Services` or `Cars`.

### 7.2 Item shape

Every Item supports common merchandising/presentation data:

- title;
- images;
- description;
- price;
- typed additional attributes;
- active/archive state.

Additional attributes can differ by Catalog.

Examples:

```text
Cars
  transmission
  seats
  fuel_type
```

```text
Properties
  bedrooms
  area
  property_type
```

```text
Services
  category
  estimated_duration
```

These are data attributes, not subtype behavior.

### 7.3 Catalog Selector Block

A Stage can expose a selector for one Catalog:

```text
Label: Requested service
Catalog: Services
Mode: Single
Key: requested_service
```

or:

```text
Label: Vehicle
Catalog: Cars
Mode: Single
Key: vehicle
```

or:

```text
Label: Extras
Catalog: Add-ons
Mode: Multiple
Key: extras
```

Rules and completion predicates can inspect selected Item identity, price, and supported attributes.

### 7.4 No `bookable` concept by default

An Item does not need to declare:

```text
bookable = true
```

Selection is just Conversation state.

If later the product genuinely needs inventory reservation or item-level capacity/conflict guarantees, that is a separate scheduling/reservation requirement and should be modeled deliberately.

---

## 8. Appointments

### 8.1 Meaning

Appointment is the canonical scheduling entity.

A user may call the action a booking, but the durable record is Appointment.

Appointment is a time-bound commitment associated with a Conversation.

Examples:

- phone consultation;
- site visit;
- vehicle pickup;
- property viewing;
- installation;
- delivery;
- follow-up.

### 8.2 Independence from Items

These configurations must all work:

```text
Appointment without selected Item       YES
Item selected without Appointment       YES
Appointment before Item selection       YES
Item selection before Appointment       YES
multiple Item selections                YES
multiple Appointments                    YES
no Catalog at all                        YES
```

### 8.3 Shared context instead of hard coupling

Suppose the Conversation contains:

```text
Selected vehicle: Range Rover Evoque
Appointment: Pickup tomorrow at 14:00
```

The operator who receives/views the Appointment should also see relevant Conversation context, including the selected vehicle.

Reservi does not need to infer that the vehicle is a special `bookable Resource`. The configured Flow gave the combination its meaning.

Likewise:

```text
Selected Item: Garden Maintenance
Appointment: Site visit
```

and:

```text
Selected Item: Villa Agdal
Appointment: Property viewing
```

are simply composed state.

### 8.4 Multiple Appointments

One Conversation may have distinct logical Appointments such as `site_visit`, `installation`, `pickup`, and `follow_up`.

Configured Blocks need stable keys so completion predicates address the intended Appointment.

---

## 9. Rules, routing, and assignment

Use one condition model rather than separate routing/assignment/completion languages.

Examples:

```text
IF City = Marrakech
THEN Assign Ahmed
```

```text
IF Requested Service.category = irrigation
THEN Assign Irrigation Team
```

```text
IF Property.area = Marrakech
THEN Assign Sarah
     Send intro message
```

Assignment domain logic still owns one-current-owner integrity and history. The Rule merely invokes it.

Stage completion is separate:

```text
Complete when City exists AND Owner exists
```

---

## 10. Human and AI operation

The current Stage is the shared operational contract.

Example:

```text
Current Stage: Pickup

✓ Customer identified
✓ Vehicle selected: Range Rover Evoque
○ Pickup Appointment confirmed
```

A human sees the same goal an AI sees.

AI can update allowed Fields, select allowed Items, create/manage Appointments, send Messages, or assign/handoff only through granted capabilities and server-side validation.

Flow configuration—not prompt prose—is authoritative process intent.

---

## 11. Inbox and Conversation workspace

The inbox should expose actionable state without becoming a spreadsheet CRM.

Useful context includes:

- Customer;
- current Stage;
- current owner/team;
- attention/unread state;
- relevant configured Fields;
- selected Items relevant to the process;
- blocked/missing requirement where useful.

From the Conversation an Agent should be able to perform the current Stage's work without excessive navigation.

Appointment surfaces should display relevant Conversation context, including selected Items, rather than duplicating them into Appointment-specific business columns.

---

## 12. Flow runtime

On relevant state mutation:

```text
persist authorized state change
        ↓
evaluate applicable current-Stage Rules
        ↓
execute newly applicable Actions safely
        ↓
re-read authoritative state
        ↓
evaluate completion predicate
        ↓
if complete -> advance to next Stage
```

Requirements:

- deterministic evaluation;
- explicit Rule priority/order;
- loop protection;
- idempotency for irreversible Actions;
- race-safe Stage advancement;
- explainability/audit for meaningful automated actions;
- server-side truth.

Initial product should use ordered Stages rather than an arbitrary graph.

---

## 13. Feature integration contract

A new first-class feature should integrate by exposing:

```text
Feature = State + Controls + Predicates + Actions
```

Example Quote:

- State: quote.status, quote.total;
- Control: Quote Builder;
- Predicates: quote exists / accepted;
- Actions: create/send quote.

Then a Stage can require Quote acceptance without changing the central Flow engine.

Catalog/Item itself follows this philosophy: Item selection is state, Catalog Selector is the control, predicates inspect Items, actions can select/clear them.

---

## 14. Multi-tenancy

Each Account owns its:

- Flows / Stages / Rules;
- Field Definitions;
- Catalogs / Items;
- Agents / Teams;
- Customers / Conversations;
- Appointments;
- Channels / Integrations.

A configuration or runtime operation must never reference another Account's Item, Catalog, Agent, Stage, Field, Appointment, Customer, or Conversation.

---

## 15. Reliability requirements

High-risk cases include:

- duplicate messaging webhooks;
- repeated Rule evaluation;
- Rule Action retry;
- concurrent assignment;
- concurrent Stage completion/advancement;
- stale UI;
- configuration changed while Conversations are in flight;
- Item archived/changed after selection;
- Appointment changed while a Stage depends on it.

Durable invariants require database/transaction protection where appropriate.

Selected Item title, price/currency/unit and predicate-relevant attributes are snapshotted at selection. Predicates read that selected context; explicit refresh/reselection is required to adopt listing changes. See `domain-model.md` §31.

---

## 16. Configuration evolution

Flow/Catalog configuration affects live Conversations, so destructive edits need explicit semantics.

Examples requiring deliberate behavior:

- Stage renamed/reordered/archived;
- required Block removed;
- Rule/completion expression changed;
- Field Definition changed;
- Catalog archived;
- Item archived/deleted;
- Item attributes changed while selected;
- Agent removed.

Published FlowVersions are immutable and Conversations remain pinned to them. Structural edits produce a new draft/version; automatic migration of active Conversations is deferred. Referenced field types remain stable, Catalog selections retain snapshots, and deactivated targets produce visible remediation.

---

## 17. Deliberate non-goals

Reservi is not trying to become:

- Salesforce clone;
- BPMN engine;
- Zapier/n8n replacement;
- arbitrary graph workflow editor;
- general-purpose scripting runtime;
- Airtable-style universal entity database;
- a type hierarchy for every business vertical;
- event-sourced platform;
- microservice mesh.

Do not create separate `Service`, `Car`, `Room`, and `Property` workflow engines/models merely because the business vocabulary differs.

Do not execute arbitrary user Ruby/JavaScript/SQL in Rules.

---

## 18. Product success criteria

Reservi is succeeding when:

- users can model their real customer process without code;
- a salon, car rental, property operation, landscaper, and agency use the same core primitives;
- Services/Cars/Rooms/Properties are just Catalog Items rather than architectural forks;
- Appointment can appear anywhere without requiring Item selection;
- selected Items provide business context without a global `bookable` flag;
- operators always know what the Conversation needs next;
- AI sees the same Stage goal as humans;
- Rules are deterministic and explainable;
- system complexity grows slower than product capability.

---

## 19. Feature acceptance template

Before implementation, define:

```text
Actor:
Trigger:
Relevant Flow / Stage state:
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

For any new first-class capability also answer:

```text
What State does it expose?
What Controls does it expose?
What Predicates can inspect it?
What Actions can manipulate it?
Can existing Field or Catalog/Item express the need already?
Can it integrate without changing the core Stage engine?
```

## 20. Initial product behavior decisions

The following decisions make the above requirements concrete. They are implementation targets, not already shipped features. See [gap-audit.md](gap-audit.md) for the gaps they resolve and [implementation-plan.md](implementation-plan.md) for delivery order.

- **Process versus inbox:** a request is active, completed or cancelled; unread/needs-attention is separate. An account may complete a one-stage request with fields alone or an explicit immediate-completion gate. Completion does not universally mean service delivery.
- **Publication:** administrators edit drafts and publish immutable versions. Existing requests retain their version. Initial release has no automatic migration, backwards progression, skip or reopen; follow-up work can start a new request explicitly.
- **Corrections:** authorized operators may correct previous-stage facts. Only the current active gate is reevaluated; past completion remains historical. Shared Customer facts require separate edit permission and update all active requests' evaluated context.
- **Predictable rules:** rules run once per stage entry in visible priority order. An already executed assignment rule does not undo a later human handoff. Failed local rule actions block automation with a reason and retry control.
- **Catalog context:** chosen title/price/attributes are retained at selection time. Listing updates do not silently change the request; refreshing a selection is explicit. Archived selections remain readable. Selection never reserves inventory.
- **Appointments:** initial scheduling supports one optional scheduled human Agent, with working hours/exceptions and confirmed-slot conflict protection inside the Account. Multiple appointment roles per request are supported; item availability, recurring/group calendars and cross-account conflicts are excluded.
- **Messaging:** start with one provider. Completed requests receiving a message need attention but do not rerun their flow. Starting a new request on the same channel thread is explicit. Unknown delivery is visible and not blindly resent.
- **Access:** Account membership does not imply access to every team's work. Administrator, team manager, operator, AI and automated rules have distinct scopes/capabilities.
- **AI:** humans and AI use the same state and operations; AI has bounded usage, checked tool authority and explicit handoff. Human takeover invalidates stale AI actions and unclaimed queued AI replies.
- **Configuration UX:** preview explains outcomes without causing side effects; unsupported/invalid references fail publication with actionable errors. A logical explanation is shown for complex completion rules instead of a misleading percentage.

Support for other channels, provider-specific capabilities and production data retention is decided and verified before the corresponding release; it is not inferred from generic architecture language.
