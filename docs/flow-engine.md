# Reservi Flow Engine

## 1. Core idea

Reservi is a configurable operational flow around a Conversation.

The durable mental model is:

> A Conversation is the running process. A Stage declares what must become true next. Blocks expose ways for humans and AI to change state. Rules react to state. The Stage advances when its completion predicate becomes true.

There is no privileged sequence such as:

```text
qualification -> service -> appointment
```

A business may configure:

```text
appointment -> qualification -> catalog selection
```

or:

```text
catalog selection -> assignment -> appointment
```

or:

```text
qualification -> appointment
```

or a single Stage.

The engine must not care whether the account is a salon, rental business, property operator, landscaper, clinic, or something else.

---

## 2. Fundamental formulas

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
Completion = Predicate(Authoritative Conversation State)
```

```text
Feature integration = State + Controls + Predicates + Actions
```

A useful product sentence is:

> A Stage declares what must become true before the Conversation may proceed, and Reservi gives humans, AI, and deterministic Rules the capabilities required to make that state true.

---

## 3. Conversation is the process instance

The Conversation is the operational root.

Conceptually it exposes state such as:

```text
Conversation
├── current Stage
├── Customer
├── current Team / Owner
├── Fields
├── Catalog Item selections
├── Appointments
├── Messages / Notes
├── Assignment history
└── future feature state
```

The Conversation does not need to physically own every value as a column. This is the normalized state graph the Flow engine can observe.

Supporting entities own their own local truth while contributing state to the process.

---

## 4. Stage = Work + Gate

A Stage is not a CRM label.

It is an executable desired-state contract.

Example:

```text
Stage: Qualification

Blocks
  Name                    [customer field]
  Phone                   [customer field]
  City                    [conversation field]

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

Another Stage can contain only an Appointment:

```text
Stage: Site Visit

Block
  Site Visit              [appointment]

Complete when
  appointment("site_visit").status = confirmed
```

Another can contain only a Catalog selector:

```text
Stage: Choose Vehicle

Block
  Vehicle                 [catalog selector: Cars]

Complete when
  item_selection("vehicle") exists
```

No Stage type is privileged.

---

## 5. The four reusable primitives

### State

Durable or derived authoritative truth that can be queried.

Examples:

- Customer/Conversation fields;
- current Agent/Team;
- selected Catalog Items;
- Appointment state;
- message/customer-response state;
- later: Quote, Payment, Document state.

### Controls / Blocks

UI/agent affordances that let humans or AI manipulate state.

Examples:

- text/number/choice/date/location field;
- Catalog Item selector;
- Appointment selector/editor;
- Agent/Team selector where allowed;
- future Quote/Payment/Document controls.

### Predicates

Questions about authoritative state.

Examples:

```text
field("city") == "Marrakech"
field("budget") > 5000
owner == Ahmed
item_selection("vehicle").exists
item_selection("vehicle").attribute("category") == "SUV"
appointment("site_visit").status == confirmed
```

The same predicate model should be reused for Stage completion, assignment/routing Rules, messaging Rules, and other supported conditional behavior.

### Actions

Authorized operations that change state or schedule side effects.

Examples:

- assign Agent;
- assign Team;
- send Message;
- set/update Field;
- create/update/cancel Appointment;
- select/clear Catalog Item;
- add Note.

Rules never bypass normal domain authority.

---

## 6. Catalog is the universal selectable business inventory

Reservi should not have separate core abstractions for `Service`, `Car`, `Room`, `Property`, `Equipment`, etc.

The common abstraction is:

```text
Catalog
└── Items
```

A Catalog names a collection meaningful to the business:

```text
Catalog: Services
Catalog: Cars
Catalog: Rooms
Catalog: Properties
Catalog: Treatments
Catalog: Packages
Catalog: Products
```

An Item is the common selectable entity.

Every Item can expose the same base shape:

```text
Item
├── title
├── images
├── description
├── price
├── additional typed attributes
└── active/archive state
```

Examples:

```text
Catalog: Services
Item: Garden Maintenance
  price: 800 MAD
  attributes:
    category: maintenance
    estimated_duration: 2h
```

```text
Catalog: Cars
Item: Range Rover Evoque
  price: 1200 MAD/day
  attributes:
    transmission: automatic
    seats: 5
```

```text
Catalog: Properties
Item: Villa Agdal
  price: 3000 MAD/night
  attributes:
    bedrooms: 4
    area: Agdal
```

The Flow engine does not care what semantic category the Item represents.

---

## 7. Catalog Selector is the generic selection block

A Stage can add a Catalog Selector configured against one Catalog.

Example:

```text
Block: Requested service
Source Catalog: Services
Selection: single
Key: requested_service
```

or:

```text
Block: Vehicle
Source Catalog: Cars
Selection: single
Key: vehicle
```

or:

```text
Block: Extras
Source Catalog: Add-ons
Selection: multiple
Key: extras
```

The selected Item becomes Conversation state.

Predicates can inspect the selected Item and its attributes:

```text
item_selection("requested_service").exists
item_selection("vehicle").attribute("transmission") == "automatic"
item_selection("property").price > 2000
```

Rules can react to this state:

```text
IF item_selection("requested_service").attribute("category") == "irrigation"
THEN assign Irrigation Team
```

The selector key remains stable even if the user-facing label changes.

---

## 8. Appointment is completely independent from Catalog Item semantics

`Appointment` is the canonical scheduling entity.

It means:

> A time-bound commitment associated with a Conversation.

An Appointment may have a purpose/role such as:

- consultation;
- site visit;
- pickup;
- property viewing;
- installation;
- delivery;
- follow-up.

It may involve an Agent/participant/location as scheduling needs require.

### Critical invariant

Reservi does **not** need to know that a selected Item is "bookable".

There should be no mandatory:

```text
item.bookable = true
```

and no architectural assumption that:

```text
Appointment -> Service
Appointment -> Resource
```

must exist.

A Conversation may first select an Item from `Cars`, `Rooms`, `Properties`, or `Services`, and later create an Appointment. The operator receiving the Appointment sees the Conversation context and selected Items and understands the business meaning.

The semantic connection comes from the configured Flow and shared Conversation context, not from the application hard-coding a `bookable` subtype.

Examples that must all remain legal:

```text
Appointment with no Item selected                   YES
Catalog Item selected with no Appointment           YES
Appointment before Item selection                   YES
Item selection before Appointment                   YES
Multiple Item selections                            YES
Multiple Appointments                               YES
No Catalog at all                                   YES
```

If future product needs require explicit item-level inventory reservation/conflict protection, introduce that requirement deliberately as a scheduling/reservation policy. Do not pre-classify every Catalog Item as bookable now.

---

## 9. Appointment context comes from the Conversation

This is an important product simplification.

Suppose the Conversation contains:

```text
Selected Item
Catalog: Cars
Item: Range Rover Evoque

Customer
Khalid

Appointment
Pickup
Tomorrow 14:00
```

The operator viewing the Appointment should see the relevant Conversation context, including the selected Item.

The application does not need to infer:

```text
Range Rover Evoque is a bookable resource
```

The Flow already established the meaning by asking for a car selection and later asking for an Appointment.

Likewise:

```text
Selected Item: Garden Maintenance
Appointment: Site visit
```

or:

```text
Selected Item: Villa Agdal
Appointment: Property viewing
```

are simply combinations of independent state.

---

## 10. Fields remain for arbitrary structured facts

Catalog Items should not replace Fields.

Use Fields for facts such as:

- name;
- phone;
- city;
- budget;
- surface;
- urgency;
- notes/requirements;
- boolean/choice/date values.

Fields have explicit scope:

- Customer/profile;
- Conversation/request.

Use Catalog selectors when the user is choosing one or more rich reusable Items with title/media/description/price/attributes.

A good heuristic:

> If the value deserves its own reusable card/listing, it is probably an Item. If it is a fact about the Customer/request, it is probably a Field.

---

## 11. Stable role keys

Stateful Blocks need stable keys so multiple instances remain unambiguous.

Examples:

```text
Catalog selector
Label: Vehicle
Key: vehicle
```

```text
Catalog selector
Label: Property
Key: property
```

```text
Appointment
Label: Site visit
Key: site_visit
```

Then predicates can say:

```text
item_selection("vehicle").exists
appointment("site_visit").status == completed
```

Keys must survive label changes.

---

## 12. Routing and assignment are ordinary Actions

Do not build separate routing and assignment languages.

Example:

```text
IF field("city") == "Marrakech"
THEN assign_agent(Ahmed)
```

or:

```text
IF item_selection("requested_service").attribute("category") == "irrigation"
THEN assign_team(Irrigation Team)
```

or:

```text
IF item_selection("property").attribute("area") == "Marrakech"
THEN assign_agent(Sarah)
     send_message("Sarah will handle your request.")
```

The Assignment domain still owns owner integrity/history. Rules only invoke it.

---

## 13. Runtime semantics

On relevant state change:

```text
STATE CHANGED
      ↓
Evaluate current-Stage Rules
      ↓
Execute newly applicable authorized Actions
      ↓
Re-read authoritative state
      ↓
Evaluate completion predicate
      ↓
Complete?
  ├─ no  -> remain in Stage
  └─ yes -> advance to next Stage
```

Relevant changes include:

- Field update;
- Catalog Item selection/clearing;
- Appointment mutation;
- owner/team change;
- Message state where a predicate depends on it;
- future feature state changes.

Evaluation must be deterministic, tenant-scoped, retry-safe, loop-protected, race-aware, and explainable.

A true predicate remaining true must not repeatedly execute the same irreversible Action.

---

## 14. Explainability

Users should be able to understand why something happened or why progression is blocked.

Example:

```text
Assigned to Ahmed
Reason:
Stage: Qualification
Rule: Marrakech requests
Matched: City = Marrakech
```

Example blocked Stage:

```text
Qualification — 3/4 complete

✓ Name
✓ Phone
✓ City
○ Owner must be assigned
```

Example Catalog-based Stage:

```text
Vehicle Selection — incomplete

○ Select one Item from Cars
```

The same state should be machine-readable by AI Agents.

---

## 15. Human and AI symmetry

The Stage is the shared operational contract.

If a Stage requires:

```text
Name
City
Vehicle selection
Confirmed pickup Appointment
```

then both a human and AI should be able to identify what is missing from the same authoritative state.

The AI may fill allowed Fields, select an Item, send Messages, assign/handoff, or create an Appointment only through granted capabilities and normal domain validation.

Do not encode the business process only in the AI prompt. Flow configuration is authoritative operational intent.

---

## 16. Future feature integration

New first-class features should integrate through:

```text
Feature = State + Controls + Predicates + Actions
```

Example Quote:

```text
State:
  quote.status
  quote.total

Control:
  Quote Builder

Predicates:
  quote.exists
  quote.status == accepted

Actions:
  create_quote
  send_quote
```

Then a Stage can require:

```text
quote("proposal").status == accepted
```

without adding Quote-specific transition code to the central engine.

---

## 17. Boundaries: flexible, not infinitely generic

Reservi is not n8n, Zapier, Airtable, Salesforce Flow, or a general programming environment.

Keep genuine domain concepts explicit:

```text
Conversation
Customer
Agent
Team
Catalog
Item
ItemSelection
FieldDefinition / FieldValue
Appointment
Flow
Stage
Rule
Message
```

Do not create a universal Entity/Property/Relation/Node/Edge meta-model.

Catalog/Item is deliberately generic only for the class of **reusable things a business presents/selects**. It does not replace Customer, Agent, Appointment, Conversation, or other concepts with their own lifecycles/invariants.

---

## 18. Initial scope constraints

Start with ordered Stages, not an arbitrary graph editor.

Initial semantics:

- Flow has ordered Stages;
- Conversation has one current Stage;
- Stage has Blocks;
- Stage has Rules;
- Stage has one completion expression composed from supported predicates;
- completing a Stage advances to the configured next Stage;
- terminal Stage completes/closes the Flow according to explicit configuration.

Do not initially introduce branching graphs, loops, timers, parallel stages, generic webhooks, arbitrary scripting, or arbitrary code expressions.

The power should come from composition of a few primitives, not from an unlimited workflow language.
