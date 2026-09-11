# Reservi Domain Model

## 1. Modeling philosophy

Reservi uses a small set of durable concepts that represent real operational work while allowing each Account to configure how a customer request progresses.

Two rules dominate the model:

> A lead is the Conversation.

> A Conversation progresses because its current Stage declares what state must become true next.

Do not hard-code vertical-specific concepts such as `Service`, `Car`, `Room`, or `Property` as different workflow primitives. Reusable selectable business objects are modeled uniformly as `Catalog` + `Item`.

Read `docs/flow-engine.md` before changing Flow, Stage, Field, Rule, Catalog, Item, Appointment, or assignment concepts.

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
├── Catalogs
│   └── Items
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
    ├── Item Selections
    ├── Messages / Notes
    ├── Appointments
    └── Assignment / state history
```

This is conceptual. The final schema may introduce support/join records where correctness requires them.

---

## 3. Account

The tenant/organization whose data and configuration are isolated from every other tenant.

Account owns/scopes its operational configuration and records, including:

- Agents / Teams;
- Channels / Integrations;
- Customers / Conversations;
- Flows / Stages / Rules;
- Field Definitions;
- Catalogs / Items;
- Appointments;
- account settings.

Cross-account references are invalid even inside configuration.

---

## 4. User

An authenticated human identity.

A User is not automatically an operational Agent in every Account. Human authentication/membership and operational Agent identity remain distinct enough to support multi-account use safely.

AI Agents must not be modeled as Users merely to reuse authentication fields.

---

## 5. Agent

An operational actor capable of performing work.

Human and AI actors share one conceptual `Agent` abstraction.

Capabilities may include:

- receive assignment;
- read Conversation context;
- reply to Customer;
- add Notes;
- update allowed Fields;
- select allowed Catalog Items;
- create/change Appointments;
- execute allowed Actions;
- hand off/reassign.

AI-specific runtime/model/instructions/tools belong in configuration/capabilities, not in parallel operational models.

---

## 6. Team

A group of Agents used for routing, ownership eligibility, queueing, permissions, or organization.

A Team may be selected by a Rule action. Team is not a workflow node.

---

## 7. Customer

The account-scoped person or organization interacting with the business.

Customer owns durable profile facts meaningful across Conversations, such as:

- name;
- phone;
- email;
- language/locale;
- stable profile information;
- normalized channel identities.

Request-specific facts normally belong to Conversation-scoped Fields instead of Customer.

---

## 8. Channel / Integration

A configured external communication or service integration belonging to an Account.

Provider-specific transport/payload/status behavior remains at the integration boundary. Core domain code uses normalized concepts.

---

## 9. Conversation

The central operational record and process instance for a customer request.

A Conversation is the lead.

Conceptually it exposes authoritative state including:

- Account;
- Customer;
- channel/context;
- current Flow / Stage;
- current Team / Agent owner;
- Customer/Conversation Field Values;
- Catalog Item Selections;
- Messages / Notes;
- Appointments;
- Assignment history;
- useful state/audit history.

The Conversation is the process root. Supporting entities own their local truth while contributing state to progression.

Do not duplicate current Stage, owner, Appointment state, Item selection, or other canonical facts in a separate Lead/Deal tree.

---

## 10. Flow

An Account-configured ordered operational progression.

The initial product models Flow as an ordered set of Stages, not an arbitrary graph language.

A Conversation follows a Flow and has one authoritative current Stage.

---

## 11. Stage

A Stage is an executable desired-state contract, not merely a CRM status label.

```text
Stage = Blocks + Rules + Completion Predicate
```

A Stage answers:

1. What controls/capabilities should be exposed now?
2. What deterministic reactions should happen as state changes?
3. What must be true before the Conversation can proceed?

No specific Stage sequence is mandatory.

An Appointment may be required in Stage 1. A Catalog selection may happen later. Some Flows may never use either.

---

## 12. Stage Block

A configurable product-facing control/capability exposed inside a Stage.

Examples:

- Field input;
- Catalog Item selector;
- Appointment selector/editor;
- controlled Agent/Team selection;
- future Quote/Payment/Document controls.

A Block is configuration, not automatically a database model.

Stateful Blocks need stable logical keys when several instances of the same capability may exist.

Examples:

```text
vehicle
requested_service
site_visit
installation
```

Display labels may change; stable keys must not silently change meaning.

---

## 13. Predicate / Expression

A deterministic question over normalized authoritative state.

Examples:

```text
field("city") == "Marrakech"
field("budget") > 5000
owner.exists
item_selection("vehicle").exists
item_selection("vehicle").attribute("category") == "SUV"
appointment("site_visit").status == confirmed
```

Reservi should use one shared predicate model for Stage completion, assignment/routing Rules, messaging Rules, and other supported conditions.

Predicates cannot execute arbitrary Ruby/JavaScript/SQL.

---

## 14. Rule

A persisted configurable reaction within a Stage/Flow.

```text
Rule = Predicate + Actions
```

Example:

```text
IF field("city") == "Marrakech"
THEN assign_agent(Ahmed)
     send_message("Ahmed will handle your request.")
```

Rules need explicit priority/order and idempotency semantics.

A predicate remaining true must not repeatedly trigger the same irreversible logical action.

---

## 15. Action

An authorized domain operation invoked by a Rule, human, AI, or API.

Examples:

- assign Agent;
- assign Team;
- send Message;
- update Field;
- select/clear Catalog Item;
- create/update/cancel Appointment;
- add Note.

A Rule never receives privileged mutation access. It invokes the same protected operation other actors use.

---

## 16. Field Definition and Field Value

Configurable structured facts.

A Field Definition may contain:

- stable key;
- label;
- data type;
- allowed options;
- validation constraints;
- target scope (`customer` or `conversation`);
- display/order metadata;
- AI editability/capability settings where useful.

Typical types:

- text;
- number;
- boolean;
- single/multi choice;
- date/time;
- location/address.

Use Fields for facts about a Customer/request.

Examples:

```text
name
phone
city
budget
surface
urgency
problem_description
```

Do not dynamically create schema columns per customer-defined Field. Do not place all durable truth in unvalidated JSON either.

---

## 17. Catalog

An Account-owned collection of reusable selectable Items.

Catalog is intentionally generic across business verticals.

Examples:

- Services;
- Cars;
- Rooms;
- Properties;
- Treatments;
- Packages;
- Products;
- Add-ons.

Catalog itself primarily provides identity, presentation/configuration, ordering, and Item grouping.

Do not create separate core domain models solely because one Catalog is called `Services` and another is called `Cars`.

---

## 18. Item

A reusable selectable entity inside a Catalog.

All Items share a common base concept:

```text
Item
├── Catalog
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
```

```text
Catalog: Cars
Item: Range Rover Evoque
```

```text
Catalog: Properties
Item: Villa Agdal
```

From the Flow engine's perspective these are all Items.

### Additional attributes

Different Catalogs may define additional typed attributes for their Items.

Examples:

```text
Cars:
  transmission
  seats
  fuel_type

Properties:
  bedrooms
  area
  property_type

Services:
  category
  estimated_duration
```

Attributes are data, not subtype behavior.

### No global bookable flag

Core Item semantics must not assume an Item is bookable/schedulable.

Do not require:

```text
item.bookable
```

or type-specific inheritance such as:

```text
ServiceItem
CarItem
RoomItem
```

solely to drive Appointment behavior.

---

## 19. ItemSelection

Represents one or more Catalog Items selected into Conversation state through a configured Catalog Selector Block.

Conceptually:

```text
ItemSelection
├── Conversation
├── selector/block key
├── Catalog
└── selected Item(s)
```

Examples:

```text
item_selection("requested_service") = Garden Maintenance
item_selection("vehicle") = Range Rover Evoque
item_selection("property") = Villa Agdal
```

A selector may allow single or multiple selection.

The stable selector key gives Rules and completion predicates an unambiguous reference.

Selection does not inherently mean reservation, scheduling, ownership, or booking. It means the Item is part of Conversation state in that configured role.

---

## 20. Appointment

`Appointment` is the canonical durable scheduling entity.

The word `booking` may describe the user action of reserving time, but the domain entity is Appointment.

Definition:

> A time-bound commitment associated with a Conversation.

Appointment may include:

- Account;
- Conversation;
- stable logical role/key when created through a Stage Block;
- starts_at;
- ends_at/duration;
- status;
- participating Agent(s) where needed;
- location/context as needed;
- creator/actor attribution.

### Appointment is independent from Item

Appointment does not require a selected Item.

Item selection does not require an Appointment.

These must remain valid:

```text
Appointment without Item selection      YES
Item selection without Appointment      YES
Appointment before Item selection       YES
Item selection before Appointment       YES
multiple Item selections                YES
multiple Appointments                    YES
no Catalog at all                        YES
```

### No hidden bookability inference

If a Conversation selects `Range Rover Evoque` from the Cars Catalog and later creates a Pickup Appointment, the operator sees both through Conversation context and understands their business relationship.

The core app does not need to label the Item `bookable` or force an Appointment -> Item relationship to make that Flow valid.

If explicit item-level inventory reservation becomes a real future requirement, model that requirement deliberately rather than retroactively treating all Items as scheduling resources.

### Multiple Appointments

One Conversation may contain `site_visit`, `installation`, `pickup`, `follow_up`, etc. Predicates identify the intended Appointment through stable role/key/reference.

---

## 21. Assignment

Conversation has one authoritative current Agent owner under normal operation, plus truthful history.

Assignment may originate manually, from AI, or from a Rule Action. All origins pass the same eligibility/account/authorization/concurrency boundary.

Example:

```text
IF city == Marrakech
THEN assign Ahmed
```

The Rule engine does not own assignment truth; the assignment operation does.

---

## 22. Message

A customer-visible inbound/outbound communication belonging to a Conversation.

Message handles normalized content/direction/provider identity/delivery state/sender attribution.

Inbound duplicate provider delivery must be safe. Outbound retries must not casually double-send.

---

## 23. Internal Note

Internal collaboration content that must never be accidentally delivered through a customer-facing channel.

---

## 24. Appointment/calendar UI relationship to Catalog Items

Calendar and Appointment surfaces should display useful Conversation context, including selected Items, when relevant.

Example Appointment card/detail:

```text
Pickup — 14:00
Customer: Khalid
Owner: Ahmed
Selected vehicle: Range Rover Evoque
```

The UI obtains `Selected vehicle` from Conversation ItemSelection state. This does not imply the Appointment model owns or understands vehicle semantics.

This separation is intentional.

---

## 25. Future feature integration contract

A future first-class feature should integrate into Flow through:

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

The central Flow engine should not gain feature-specific transition logic.

---

## 26. History and audit

Prefer domain-specific truthful history:

- Messages;
- Notes;
- Assignments;
- Appointment changes;
- Stage transitions;
- Rule/Action executions where needed;
- significant Field/ItemSelection changes where operationally useful.

A unified timeline can project these records without becoming a second source of truth.

---

## 27. Concepts explicitly rejected as defaults

Do not introduce these merely for flexibility:

- Lead / Opportunity / Deal parallel to Conversation;
- Service as a privileged Flow primitive;
- Resource / ResourceType when Catalog / Item already expresses the selectable object;
- mandatory Item/Service on Appointment;
- `bookable` flag as a prerequisite for Appointment use;
- separate `Booking` and `Appointment` truths;
- separate routing/assignment/completion condition engines;
- separate AI workflow engine;
- arbitrary code/script expressions in Rules;
- generic graph Nodes/Edges before real branching requirements;
- universal Entity/Property/Relation meta-schema.

---

## 28. Concept admission test

Before adding a model/table, answer:

1. What real-world concept does it represent?
2. Who owns it?
3. What independent lifecycle/invariant does it own?
4. Can a Field express it if it is just a fact?
5. Can Catalog/Item express it if it is a reusable selectable thing?
6. Can Appointment express it if it is a time-bound commitment?
7. Can existing State + Controls + Predicates + Actions integrate it cleanly?
8. Does it duplicate existing truth?
9. How is it tenant-scoped and authorized?
10. Would adding it make the common mental model simpler or harder?

If these answers are weak, do not add the concept.
