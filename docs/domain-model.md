# Reservi Domain Model

## 1. Modeling philosophy

Reservi uses a small set of durable concepts that reflect real operational work.

The model should stay understandable without an internal framework or CRM vocabulary translation layer.

The central rule is:

> A lead is the conversation.

Do not create parallel Lead / Opportunity / Deal records to represent stages of the same customer interaction.

The domain should answer practical questions:

- Who is the customer?
- What are they asking for?
- Which conversation contains the truth?
- Who currently owns it?
- Which team is responsible?
- What has been said?
- What information has been qualified?
- Is there a booking?
- What happened over time?
- Which human or AI agent performed an action?

---

## 2. Conceptual relationship map

```text
Account
 ├── Channels / Integrations
 ├── Customers
 ├── Teams
 │    └── Agent memberships
 ├── Agents
 │    ├── human-backed
 │    └── AI-backed
 ├── Conversations
 │    ├── Customer
 │    ├── Channel
 │    ├── current Team
 │    ├── current Agent
 │    ├── Messages
 │    ├── Notes
 │    ├── Qualification values
 │    ├── Assignment history
 │    └── Bookings
 └── Services / scheduling configuration (as needed)
```

This diagram is conceptual. The eventual database schema may introduce join/supporting records, but it should preserve this mental model.

---

## 3. Account

### Meaning

The tenant/organization whose data and configuration are isolated from other tenants.

Examples:
- one salon business;
- one landscaping company;
- one agency client organization;
- one multi-location service company.

### Owns or scopes

- customers;
- conversations;
- channels/integrations;
- teams;
- agents/memberships;
- bookings;
- qualification definitions;
- services/resources/locations where applicable;
- account settings.

### Core invariants

- tenant-owned records cannot cross accounts;
- account-scoped uniqueness must be explicit;
- external channel/integration identity resolves to exactly the intended account context.

---

## 4. User

### Meaning

An authenticated human identity that can access Reservi.

A User is not automatically equivalent to an operational Agent in every account.

A person may belong to multiple accounts or participate through memberships according to future product needs.

### Responsibilities

- authentication identity;
- human profile/session/security concerns;
- links to account membership and operational Agent identity.

Do not put AI agents into User solely to reuse authentication fields.

---

## 5. Agent

### Meaning

An operational actor that can own or perform work.

Agent is the common conceptual abstraction for humans and AI.

### Common capabilities may include

- receive assignment;
- read conversation context;
- reply to customer;
- add internal note;
- update qualification;
- change allowed conversation state;
- create/manage booking;
- hand off/reassign;
- invoke configured tools.

### Human-backed Agent

References the appropriate authenticated user/account membership identity.

### AI-backed Agent

References configuration such as:
- instructions/system context;
- model/provider/runtime;
- allowed tools;
- action capabilities;
- escalation/approval behavior.

### Important modeling rule

Do not create separate `HumanAssignment`, `AiAssignment`, `HumanMessage`, `AiMessage`, etc. unless a genuine invariant requires it.

Actor type is a property of the Agent/configuration; operational records should usually reference Agent uniformly.

---

## 6. Team

### Meaning

A group of Agents used for routing, ownership eligibility, permissions, or operational organization.

Examples:
- Sales;
- Reception;
- Marrakech location;
- Plumbers;
- After-hours support;
- Client A operators in an agency setup.

### Expected relations

- belongs to Account;
- has Agent memberships;
- may own/queue Conversations;
- participates in routing rules.

### Rule

Team should remain an understandable routing/organizational concept, not become a generic workflow node.

---

## 7. Customer

### Meaning

The account-scoped person or business contacting the service provider.

### Possible attributes

- display name;
- normalized phone(s);
- email(s);
- locale/language;
- account-scoped profile data;
- channel identities.

### Identity rules

Customer resolution is account-scoped.

The same phone/email appearing in different accounts must not cause cross-tenant identity merging.

Channel/provider-specific identities should be normalized through an identity relation or explicit fields appropriate to the implementation rather than leaking raw payload structures throughout the system.

---

## 8. Channel / Integration

### Meaning

A configured external communication or service integration belonging to an Account.

Examples:
- WhatsApp Business number;
- email inbox;
- SMS number;
- future social messaging channel;
- external calendar integration.

### Responsibilities

- credentials/configuration reference;
- provider identity;
- account resolution for inbound traffic;
- adapter selection;
- channel-specific capabilities/settings.

### Rule

Provider-specific payload behavior stays at the integration boundary.

Core Conversation/Message behavior should use normalized concepts.

---

## 9. Conversation

### Meaning

The central operational record for a customer interaction and the primary CRM object.

A Conversation is the lead.

### Expected responsibilities/data

- Account;
- Customer;
- communication/channel context;
- operational state;
- current Team;
- current Agent/owner;
- latest activity/attention metadata;
- structured qualification context;
- Messages;
- internal Notes;
- Assignment history;
- Bookings;
- useful audit/state history.

### What should not be duplicated elsewhere

Do not create separate lead records containing:
- current owner;
- qualification;
- pipeline state;
- booking status;
- conversation-derived activity

unless a distinct domain lifecycle is proven.

### Lifecycle

Exact states should be compact and based on operational needs. Candidate meanings include:

- open/new;
- awaiting response/customer;
- qualified;
- booking pending;
- booked;
- active/in service;
- completed;
- closed/cancelled/lost.

Do not freeze these exact labels until implementation/product usage confirms them. The invariant is that state remains understandable and compact rather than becoming an arbitrary pipeline builder.

### Ownership

Conversation normally has one authoritative current owner at a time.

A current team may also represent the queue/responsibility scope.

Assignment history records transitions; it does not compete with current-owner truth.

---

## 10. Message

### Meaning

A customer-visible inbound or outbound communication in a Conversation.

### Core properties

- Conversation;
- Account by ownership path/direct scope as implementation dictates;
- direction (inbound/outbound);
- sender/actor attribution;
- content;
- attachments/media;
- provider/channel identity;
- provider message ID where present;
- delivery state where supported;
- timestamps/order data.

### Sender model

Inbound customer message: attributable to customer/channel identity.

Outbound message: attributable to the acting Agent and external channel.

Automated/AI messages still identify an Agent where they are operational acts.

### Idempotency

A stable provider message/event identity should prevent duplicate persistence/sends where possible.

### Ordering

Do not depend solely on job completion order. Use provider/event timestamps and durable local sequence/time semantics appropriate to the channel.

---

## 11. Internal Note

### Meaning

An internal collaboration entry visible to authorized operators but never sent to the customer.

### Why separate from Message

The visibility invariant is materially different.

It may still appear in the conversation timeline, but customer-facing transport must never accidentally include it.

### Expected fields

- Conversation;
- author Agent;
- body/content;
- timestamp;
- optional references/mentions later.

---

## 12. Assignment

### Meaning

A historical record that a Conversation was assigned/handed to an Agent (and potentially Team) over a time range or transition.

### Authoritative current state

There should be a single efficient authoritative representation of current ownership on/through Conversation.

Assignment records preserve history and attribution.

### Possible fields

- Conversation;
- Agent;
- Team if relevant;
- assigned_at;
- ended_at / superseded_at;
- assigned_by Agent/system actor;
- reason/source (manual, routing, handoff, etc.) when useful.

### Rules

- reassignment is transactional/race-safe;
- history is append-oriented rather than rewritten;
- current owner cannot diverge silently from active history semantics.

Do not create a generic work-item assignment framework unless broader requirements demand it.

---

## 13. Qualification Definition and Value

### Meaning

Structured information the business needs to qualify/serve a customer.

Different service businesses require different fields, so Reservi needs controlled configurability without turning the entire schema into unvalidated JSON.

### Definition may express

- key/name;
- label;
- data type;
- requiredness;
- allowed options;
- validation rules;
- display/order;
- service/team applicability.

### Value

Belongs to Conversation (or a clear related qualification snapshot if future requirements require versioning).

Stores validated structured value according to its Definition.

### Principles

- commonly important system fields should remain first-class where appropriate;
- AI extraction must validate against definitions;
- agents can correct values;
- do not create one database column globally for every customer's custom question;
- do not store all known business truth in one opaque unvalidated JSON blob.

---

## 14. Booking

### Meaning

A durable commitment/reservation for service associated with the relevant customer/conversation.

### Expected associations

- Account;
- Customer;
- Conversation (strongly expected for conversation-originated bookings);
- service;
- provider/resource/Agent as scheduling model requires;
- location as required.

### Core fields

- starts_at;
- ends_at or duration;
- status;
- timezone/display context via account/location/user configuration;
- resource/provider;
- booking notes/context;
- creator/actor attribution.

### Candidate statuses

- tentative/held if slot holds are introduced;
- confirmed;
- completed;
- cancelled;
- no-show as product needs arise.

Keep status compact.

### Conflict rule

When a resource cannot serve two bookings simultaneously, that invariant must survive concurrent requests.

Do not rely only on "check availability, then insert" without a concurrency strategy.

---

## 15. Service

### Meaning

A type of bookable/provided work when the scheduling/business rules require a first-class service concept.

Possible data:
- name;
- duration;
- buffer;
- active flag;
- eligible teams/agents/resources;
- location applicability;
- qualification requirements.

Do not introduce Service merely to categorize conversations if a simple qualification/category field is sufficient. Introduce it when it owns scheduling/operational behavior.

---

## 16. Location

### Meaning

A physical/operational location when multi-location routing/scheduling needs it.

Possible responsibilities:
- timezone;
- address;
- working hours;
- eligible teams/resources/services;
- routing scope.

Do not force every single-provider account to interact with Location if it adds no value. The implementation can provide sensible defaults.

---

## 17. Availability / Schedule

Availability is usually derived rather than stored as a large set of free slots.

Sources can include:
- working hours;
- resource schedule;
- time off/exceptions;
- service duration/buffers;
- existing bookings;
- location constraints.

If temporary slot holds are later necessary, model them explicitly with expiration and concurrency semantics.

---

## 18. Activity and history

Do not create a universal `Activity` table by default.

Prefer truthful domain-specific history:
- Messages;
- Notes;
- Assignments;
- Bookings and booking changes;
- selected state transitions/audit entries where required.

A unified timeline can project these records without requiring all behavior to be flattened into one generic activity model.

If a lightweight audit/event model is introduced later, it must remain a projection/audit aid rather than a second business truth system.

---

## 19. Routing Rule

Do not start by creating a generic routing DSL/model.

Implement concrete routing needs first.

A first-class routing rule becomes justified when users need configurable persisted rules with independent lifecycle/management.

Until then, deterministic domain code/configuration is preferable.

---

## 20. AI configuration

AI runtime/instructions should be modeled separately from operational Agent identity when useful.

Possible concepts:
- Agent configuration;
- instruction version/reference;
- model/provider settings;
- tool/capability grants;
- escalation rules.

Do not persist raw prompt/context duplication on every domain record unless needed for audit/debugging.

AI actions must still pass normal domain validation and permissions.

---

## 21. Concept admission test

Before adding a new model/table, answer:

1. What real-world concept does it represent?
2. Who owns it?
3. What is its lifecycle?
4. What durable truth does it own?
5. What invariants does it protect?
6. Why can it not be an attribute/association/value/derived projection?
7. Does it duplicate Conversation/Booking/Assignment/Message truth?
8. How will it be queried and authorized?
9. What happens when it is deleted/archived?
10. Would the user understand why this thing exists?

If these answers are weak, do not create the model yet.

---

## 22. Naming rules

Use product/domain language, not implementation jargon.

Prefer:
- `Conversation#assign_to`
- `Booking#cancel`
- `Team#eligible_agents`
- `Conversation#qualification_values`

Avoid vague names such as:
- `Manager`;
- `Processor`;
- `Handler`;
- `Service` when it is merely a procedural wrapper;
- `Data` / `Info` tables without a real concept.

A good domain name should make the invariant/behavior easier to infer.
