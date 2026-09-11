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

## 29. Build contract: persistence and ownership

The preceding sections define concepts. This section fixes the initial implementation choices; these are specified, not implemented. Read [architecture.md](architecture.md) for authorization and transaction boundaries.

Every account-owned table carries `account_id`; relational tenant boundaries use composite foreign keys. IDs below are references, not permission grants. All timestamps are UTC instants unless explicitly defined as local calendar data.

| Record | Initial durable shape / constraints |
|---|---|
| Account | Name, locale, IANA timezone, settings, active state |
| User / Membership | Authentication identity; unique `(account_id, user_id)`, role and active state |
| Agent | Account, kind human/ai, membership reference for human only, capabilities, active state; unique human Agent per membership |
| Team / TeamMembership | Account-scoped name; unique `(team_id, agent_id)`, active eligibility |
| Customer | Profile columns for name/phone/email/locale; validated `custom_values` JSONB; `profile_revision`; durable reevaluation marker/cursor |
| Channel | Account, provider, trusted external account identity, encrypted credential reference, intake Flow, active state |
| ChannelIdentity | Channel, provider contact identity, Customer; unique `(channel_id, external_contact_id)` |
| ChannelThread | Channel, external thread identity, ChannelIdentity, intake Conversation pointer; unique `(channel_id, external_thread_id)` |
| Conversation | Customer, ChannelThread when external, optional predecessor Conversation, pinned FlowVersion, current Stage, stage-entry identity, process status, owner/team, validated custom values, state/evaluated revisions, evaluated Customer revision, attention timestamps |
| ConversationRead | Conversation and Agent, last read Message cursor; unique `(conversation_id, agent_id)` |
| Flow | Account, name, current published version reference |
| FlowVersion | Flow, version number, draft/published state, publication time; unique `(flow_id, version_number)` |
| Stage | FlowVersion, immutable stable key, label, position, blocks/rules/completion JSONB; unique version/key and version/position |
| FieldDefinition | Account, scope, stable key, type, constraints, optional built-in binding, archive state; unique `(account_id, scope, key)` |
| Catalog | Account, title, typed attribute definitions, archive state |
| Item | Catalog, title, description, nullable decimal price, currency, unit label, typed attributes JSONB, archive state; Active Storage images |
| ItemSelection | Conversation, role key, Catalog, selected Item ID, ordinal, snapshot JSONB; unique `(conversation_id, role_key, item_id)` |
| Appointment | Conversation, role key, optional scheduled Agent, start/end, timezone, buffer snapshots, status, superseded_at, creator, revision |
| AgentAvailability | Scheduled Agent, IANA zone, weekly intervals and dated exceptions in validated configuration; one calendar per Agent |
| Message | Conversation, Channel, direction, actor, content, external message ID, operation key, delivery state, lease/attempt metadata |
| Note | Conversation, author, internal body; no transport fields or outbound job |
| WebhookReceipt | Channel, provider event key, normalized processing state, bounded retained payload, retry/lease metadata; unique Channel/event key |
| RuleExecution | Conversation, version, stage-entry identity, rule key, state, error, actor policy reference; unique Conversation/entry/rule key |
| StageTransition | Conversation, from/to Stage, entry identity, input revisions, reason, time; unique Conversation/from-entry |
| AssignmentChange / StateChange | Conversation, origin/actor, old/new permitted values or references, operation ID, time; append-only audit |
| AiRun | Conversation, AI Agent, trigger identity, input revisions/owner, state, usage, lease and error; partial unique active run per Conversation |

Supporting tables are admitted for a specific integrity or recovery need, not because every Block needs a table. Custom field values are stored in validated per-owner JSONB maps, not a universal entity-value schema. Blocks and Rules are bounded validated Stage configuration initially; they do not need separate CRUD tables. History stores necessary domain changes, not every read or a complete event-sourced world.

### Database enforcement

- Add `UNIQUE(account_id, id)` on tenant parent records used by composite references. A Conversation's `(account_id, flow_version_id, current_stage_id)` must reference a Stage in that version; Stage has the corresponding unique composite key. The published pointer on Flow must reference its own version, not another Flow's.
- `NOT NULL`, enum/status checks, positive interval checks, foreign keys, and uniqueness belong in migrations, not only Rails validation.
- Schema cannot enforce arbitrary JSON references. Publish/execute validation is mandatory, and published definitions/used field types cannot be destructively edited through application operations.
- Every selection mutation locks Conversation, validates the complete replacement set against the version's selector cardinality, then replaces it atomically. Database membership uniqueness prevents duplicates; single-versus-multiple cardinality is a transaction-protected configuration invariant.
- One current Appointment per `(conversation_id, role_key)` uses a partial unique index where `superseded_at IS NULL`. Superseded records remain in history.
- For Agent-bound confirmed Appointments, use `btree_gist` and a GiST exclusion constraint on Account equality, scheduled Agent equality, and overlap of a persisted blocked `tstzrange`. The blocked range includes the stored buffers, uses `[start, end)`, and is checked against start/end/buffer columns. Exclude rows without scheduled Agent and non-confirmed statuses. Keep this in SQL schema format if required for faithful dump/restore.
- Unique outbound Message operation keys and provider IDs are scoped by Channel and direction as appropriate. A provider's event ID, message ID and thread ID are separate identities; never substitute one for another without adapter evidence.
- Audit/selection snapshots/used definitions use restricted deletion. Account destruction is a separately designed administrative purge, not default association cascade behavior.

## 30. Conversation lifecycle and intake

`process_status` is `active`, `completed`, or `cancelled`. Active Conversations have a pinned published FlowVersion and one current Stage. Completing the terminal gate sets completed, retains the terminal Stage for context, records the transition/outcome, and stops progression. Cancellation is explicit, authorized, and records a reason. It does not cancel Appointments or send customer messages implicitly.

No automatic backward transitions, skip, reopen, or live-version migration in the pilot. A correction may make a previous gate false; history remains true about what was accepted then. Only the current active gate is reevaluated. New work after completion/cancellation starts an explicit new Conversation with a new published version; it can link to the prior request for context without duplicating its writable state.

“Needs attention” is shared inbox state derived from incoming/customer activity and explicit operator attention actions. Unread is a per-Agent read cursor. Neither changes the process status. Do not equate Flow completed with service delivered; an account may deliberately finish on qualification alone.

For provider intake, ChannelThread serializes concurrent first-message processing and has one intake Conversation pointer. Initial contact creates the Customer identity, thread, and Conversation under uniqueness/transaction protection. Subsequent messages append to that intake Conversation even when its process completed; they raise attention and do not rerun completed Rules. Starting a new request locks the thread, requires the old intake process to be completed/cancelled, creates the new Conversation, and switches the pointer atomically. Pending provider replies attach to their already identified Conversation when the adapter supplies reliable reply linkage; otherwise use the intake pointer and show provenance.

No concurrent independent intake requests on the same thread in v1. No automatic cross-channel customer merging; matching display phone/name alone is insufficient evidence. Profile phone changes do not retarget transport: ChannelIdentity remains the verified delivery identity. Channel disconnection stops new external sends and exposes queued work without deleting history.

## 31. Field and selection semantics

Built-in fields such as Customer name/phone/email/locale bind to their canonical columns. The builder may present them as Fields, but custom JSON cannot shadow these reserved keys. Date/time values are ISO-typed values; decimal numbers are exact decimal strings at external JSON boundaries, normalized server-side; choices use stable option keys.

A type/scope/key or choice meaning becomes immutable once referenced by a published Flow or stored values. Add a new definition/key and migrate deliberately if semantics change. Labels may evolve only where they do not rewrite a published definition; archive hides a field from new configuration while existing definitions/values remain interpretable. Unrecognized keys, invalid options and cross-account definitions are rejected, not silently dropped.

Editing shared Customer facts needs `edit_customer_profile`, separate from editing a request. An operator may see permitted Customer context through a visible Conversation, but cannot thereby list all that Customer's other Conversations. Customer changes are audited and trigger the durable fan-out contract in architecture §7. State readers record the profile revision they observed.

Selection snapshot includes the chosen Item ID, title, price/currency/unit and typed attributes consumed by predicates. Null price means unspecified, not free; zero means free. Decimal amount must be nonnegative when supplied, with a currency and unit label. Price comparison requires matching currency and unit; no implicit currency conversion or day/night/service-unit arithmetic.

Item listing changes do not mutate prior selection snapshots. Reselecting/refreshing a role is an explicit audited mutation under current revision and authorization. Existing archived selections remain readable and can satisfy `exists`; they cannot be newly added/refreshed from an archived listing. Catalog archive stops new selections but does not erase previous choices. Appointment views label displayed selections as current Conversation context; they do not claim to be a historical record of what was selected when the appointment was made. Consult selection history for that question.

## 32. Appointment lifecycle and calendar policy

| Operation | Preconditions | Result |
|---|---|---|
| Create proposal | Configured or ad hoc role and positive start/end interval; tenant/permission checks | Current `proposed`; no capacity hold |
| Confirm | Proposed, future start, valid calendar hours/exceptions if Agent-bound | `confirmed`; atomic exclusive blocked interval when Agent-bound |
| Reschedule | Proposed or confirmed; expected revision | Replace interval atomically, revalidate calendar and conflict; retain original on failure |
| Cancel | Proposed or confirmed | `cancelled`, reason recorded; capacity released |
| Complete | Confirmed and end time reached | `completed`; historical record retained |
| Mark no-show | Confirmed and start time reached | `no_show`; audit and capacity release |
| Replace role | Current record cancelled/completed/no_show | Supersede previous record and create new proposed record atomically |

Workspace scheduling does not require an Appointment Block: an authorized operator can create an ad hoc role using an immutable generated key such as `adhoc_<uuid>` plus a human-readable purpose and explicit duration. That namespace cannot collide with configured role keys. Ad hoc appointments are visible in Conversation/calendar and follow identical validation/conflict rules, but configured predicates address only roles declared in the pinned version. No Catalog is required.

Terminal appointment statuses cannot be quietly edited back to confirmed. Multiple roles remain possible. A role can be exposed in several Stages only with consistent semantics in the pinned version. `appointment(role)` reads the single non-superseded record, including cancelled or completed status; it never chooses the latest row arbitrarily.

Scheduled Agent is optional and separate from current Conversation owner. In the pilot, only active human Agents with calendar capability may be scheduled. Confirmation involving a scheduled Agent validates its Account, actor scope, availability configuration and exclusive interval. No calendar configured means no eligible Agent-bound slot, not unlimited availability; Agent-free commitments remain allowed. Appointment blocks define/default duration explicitly; no hidden lookup of a selected Item's duration is required.

Availability uses local weekly hours, dated closures/openings and IANA timezone. Store actual Appointment times as UTC plus chosen timezone. Reject nonexistent DST local times; require explicit offset choice for ambiguous repeated times. Show the scheduling timezone and user timezone when different. All-day appointments, recurrences, multiple participants, travel capacity, item inventory and cross-account resource guarantees are deferred.

Confirmation and availability edits lock the scheduled Agent before reading/writing its calendar configuration. Full order is Customer -> Conversation -> all affected scheduled Agent IDs in sorted order -> all affected Item IDs in sorted order. Compute a conservative complete lock set before the first action: include manual mutation targets, old/new appointment Agents, existing selected Items, and every scheduling/selection target referenced by Rules in the pinned version that evaluation may reach. V1 rule Agent/Item targets are literal validated IDs, not dynamic lookup expressions, so this set is knowable. Bound it to 100 distinct extra target rows per transaction and reject a configuration/mutation exceeding that bound before writes. Acquire the full set once; never lazily lock another lower-order target after an action. This prevents rules that schedule Agent B then A, or select an Item before scheduling, from reversing lock order across conversations. If later dynamic targets are introduced, they require a revised locking design rather than an exception. Standalone catalog/calendar writers lock their own record only and never acquire a Customer/Conversation lock afterwards. Exclusion constraints remain the final overlap guard. Avoid network I/O under any lock.

Availability edits affect future slot suggestions; they do not invalidate an already confirmed appointment. Surface affected commitments for manual resolution. Cancelling/rescheduling/completing does trigger current-stage reevaluation, but cannot rewind a completed Flow. Customer attention and operational follow-up remain visible separately.
