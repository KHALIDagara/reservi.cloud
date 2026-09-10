# Reservi Product Requirements

## 1. Purpose

Reservi is a mobile-first, conversation-centric CRM and service operations platform for service businesses, service providers, and agencies that manage inbound customer conversations and turn them into booked and completed work.

The product exists to minimize the time and friction between:

```text
customer reaches out
→ business understands the need
→ the right operator receives it
→ the customer gets a useful response
→ required information is collected
→ a booking/service commitment is created
→ the service is delivered
```

Reservi should feel like a shared messaging inbox with operational intelligence, not like a traditional CRM that forces operators to maintain separate Lead, Opportunity, Activity, and Deal records.

The CRM should maintain itself automatically as a consequence of real work.

---

## 2. Product principles

### 2.1 The conversation is the lead

A lead is not a separate record that points to a conversation.

The conversation is the operational record that carries:

- customer identity/context;
- channel identity;
- message history;
- qualification data;
- internal notes;
- current operational state;
- current owner;
- routing/team context;
- assignment history;
- booking context;
- AI context/instructions where relevant;
- activity/history required to understand what happened.

Do not force duplicate CRM bookkeeping.

### 2.2 Conversation first

The primary user experience is centered on the inbox/conversation.

From one conversation, an authorized agent should be able to understand the customer, reply, qualify, add notes, assign/handoff, change operational state, inspect history, and create/manage a booking without excessive navigation.

### 2.3 Mobile first

The core workflows must be fully usable on a phone:

- triage inbox;
- open conversation;
- read/reply;
- update qualification;
- assign/handoff;
- create/reschedule/cancel booking;
- add internal note;
- inspect essential customer/service context.

Desktop may expose more density, but no core operation should require desktop-only interaction.

### 2.4 Humans and AI are operational peers under one Agent concept

Humans and AI should participate in the same assignment and operational model.

Differences are expressed through capabilities, permissions, instructions, runtime/provider configuration, availability, and approval requirements.

AI should not be implemented as a disconnected automation product beside the CRM.

### 2.5 One clear current owner

A conversation normally has one current owner at a time.

The system must make ownership obvious, allow safe reassignment/handoff, and preserve assignment history.

### 2.6 Teams are routing units

Agents belong to teams. Teams can represent operational groups such as sales, reception, support, a location, a service line, or an agency-managed provider group.

Routing should start simple and deterministic before becoming configurable/complex.

### 2.7 Booking is the operational goal, not a separate island

For appointment/service businesses, the conversation should naturally lead to a booking.

The calendar exists to help answer: "when can this customer be served by the right provider/location?"

### 2.8 One engine, one goal

The same core product should scale from one service provider to multiple teams/locations/agents without changing its mental model.

---

## 3. Target users

### 3.1 Individual service provider

Examples: barber, plumber, landscaper, consultant, installer, technician.

Needs:
- one inbox;
- quick replies;
- customer context;
- simple qualification;
- calendar/booking;
- AI assistance;
- minimal administration.

### 3.2 Local service business

Examples: salon, dental/beauty clinic, repair business, solar installer, home-service company.

Needs:
- shared inbox;
- multiple agents;
- assignment/routing;
- availability and bookings;
- internal notes;
- role/capability control;
- handoff and accountability.

### 3.3 Multi-location / multi-provider operator

Needs:
- route conversations by location/service/team;
- distribute work across agents/service providers;
- see current ownership and booking outcome;
- avoid duplicate handling;
- preserve organization-level visibility.

### 3.4 Agency managing lead generation and operations for clients

Needs:
- multiple client organizations/locations;
- controlled data isolation;
- centralized or delegated operations;
- lead/conversation distribution;
- outcome visibility;
- support for many teams/agents without a new architecture per client.

---

## 4. Core user journeys

### 4.1 Inbound conversation to first response

1. A customer sends a message through a supported channel.
2. Reservi resolves the connected account/channel.
3. Reservi resolves or creates the customer identity.
4. Reservi resolves or creates the conversation.
5. The message appears in the appropriate inbox.
6. Routing assigns the conversation or places it in a team queue.
7. A human or AI agent reads context and responds.
8. The response is sent through the original channel.
9. Message delivery state is reconciled when the provider supports it.

Acceptance expectations:
- duplicate provider delivery must not create duplicate messages;
- account isolation must be guaranteed;
- the same active conversation should not be unintentionally duplicated for repeated messages from the same contact/channel when product rules say they belong together;
- current owner/team must be visible;
- inbound message should become actionable quickly.

### 4.2 Qualification

During a conversation, the agent can capture structured information required to serve the customer.

Examples vary by business:
- requested service;
- location/address;
- preferred date/time;
- surface/size;
- model/product;
- urgency;
- budget range;
- service-specific answers.

Requirements:
- qualification fields must be tied to the conversation/account configuration;
- the UI should not make agents edit a separate lead record;
- AI may extract/update structured qualification only within allowed fields and permissions;
- agent can correct AI-extracted data;
- structured values remain inspectable and auditable enough to understand current truth.

### 4.3 Assignment and handoff

1. Conversation enters a team/unassigned queue or is directly assigned.
2. An agent becomes current owner.
3. Owner may handle, reassign, or hand off according to permissions.
4. Previous ownership remains in history.
5. New owner receives current conversation context.

Requirements:
- only one current owner under normal operation;
- reassignment must be race-safe;
- ownership history must not be overwritten;
- unauthorized users cannot assign outside allowed scope;
- AI can participate when configured as an eligible agent.

### 4.4 Team routing

Initial routing should support deterministic rules such as:
- channel/account;
- location;
- service/category;
- explicit team;
- availability/capacity where introduced;
- round-robin or equivalent simple distribution where required.

Requirements:
- routing should be explainable;
- avoid introducing a generic workflow engine prematurely;
- manual reassignment remains possible when permissions allow;
- routing must be idempotent and race-safe.

### 4.5 Booking from conversation

1. Agent identifies the relevant service/provider/location.
2. Agent sees valid availability.
3. Agent offers/selects a slot.
4. Booking is created and associated with customer/conversation context.
5. Conversation reflects the booking outcome.
6. Agent/customer can reschedule/cancel according to product policy.

Requirements:
- booking cannot violate resource availability rules;
- concurrent attempts for the same constrained slot must be handled safely;
- booking history/status must remain truthful;
- timezone must be handled consistently;
- calendar view and conversation view should agree on the same booking truth.

### 4.6 Human ↔ AI handoff

AI can be assigned work and can hand off to humans; humans can also delegate to AI where allowed.

Examples:
- AI handles initial qualification then assigns to salesperson;
- human asks AI to draft/respond while retaining ownership;
- AI escalates when confidence/rule threshold requires human judgment;
- AI creates a booking only if its capabilities allow it and domain validations pass.

Requirements:
- prompts do not bypass authorization;
- AI actions are validated server-side;
- operationally important actions are attributable to the acting Agent;
- handoff preserves conversation context;
- the system should not require a parallel "automation conversation".

### 4.7 Completion and follow-up

Conversation/service state should support a meaningful completion lifecycle.

Examples:
- new/open;
- awaiting customer;
- qualified;
- booking pending;
- booked;
- in service / active;
- completed;
- closed/lost/cancelled as applicable.

Exact states should stay compact and domain-driven. Do not build an infinitely configurable sales pipeline until real use requires it.

---

## 5. Functional requirements

### 5.1 Accounts / organizations

The system must support independent organizations/accounts.

Each account owns its operational configuration and data, including as applicable:
- customers;
- conversations;
- channels;
- teams;
- agents/memberships;
- bookings;
- qualification definitions;
- integrations;
- account settings.

Hard requirement: one account must not access another account's data.

### 5.2 Users and agents

A human user may participate as an Agent in one or more authorized account/team contexts.

AI agents are also Agents with additional configuration such as:
- instructions;
- model/provider/runtime reference;
- enabled capabilities;
- tool/action permissions;
- escalation/handoff behavior.

Do not assume every User is an Agent in every account.

### 5.3 Teams

Teams group eligible agents and help define routing/access.

Minimum capabilities:
- create/update team;
- add/remove agent membership;
- assign conversation to team/current agent;
- filter inbox by team;
- preserve tenant boundary.

### 5.4 Customers

Customer identity should be simple and channel-aware.

Expected information may include:
- display name;
- phone;
- email;
- external/channel identifiers;
- locale/language;
- account-scoped metadata/contact details.

Identity resolution must avoid accidental cross-account merging.

### 5.5 Conversations

Conversation must support:
- account ownership;
- customer association;
- channel/context;
- current team and current owner as needed;
- operational state;
- unread/attention state as needed;
- qualification data;
- messages;
- internal notes;
- assignment/state history;
- related bookings;
- timestamps for meaningful inbox ordering.

Conversation should remain the primary surface for daily work.

### 5.6 Messages

Message requirements:
- inbound and outbound;
- sender/actor attribution;
- channel/provider identity;
- textual content;
- attachments when supported;
- provider message/event IDs;
- delivery lifecycle where available;
- stable chronological ordering;
- duplicate-delivery safety.

Internal notes should be distinguishable from customer-visible messages.

### 5.7 Qualification

The product should support account/service-specific structured qualification without hardcoding every business type into the global schema.

Use a controlled flexible model: definitions are configured, values are validated, and frequently queried core fields should not disappear into opaque blobs without need.

The exact storage design belongs to architecture/domain implementation, but the UX must feel native to the conversation.

### 5.8 Inbox

Inbox must provide fast operational triage.

Expected capabilities over time:
- assigned to me;
- unassigned/team queue;
- unread/needs attention;
- state filters;
- team filters;
- search;
- recent activity order;
- clear current owner/state/customer/service context.

Do not overload the inbox with CRM columns that are not actionable.

### 5.9 Calendar and bookings

Booking must support as product needs emerge:
- service duration;
- provider/resource/location;
- start/end;
- timezone-aware display;
- status;
- reschedule/cancel;
- conflict prevention;
- link to customer/conversation;
- notes/context needed by the service provider.

Availability rules may include working hours, exceptions, duration, buffers, provider/resource constraints, and location constraints. Build the smallest correct model first.

### 5.10 Internal collaboration

Agents should be able to:
- add internal notes;
- mention/handoff where appropriate;
- see assignment/history;
- share the same conversation truth without duplicating records.

### 5.11 AI assistance and autonomous operation

AI capabilities may include:
- summarizing conversation;
- extracting qualification data;
- drafting replies;
- sending replies if permitted;
- selecting a routing/handoff action if permitted;
- creating/managing bookings if permitted;
- adding internal notes;
- identifying missing information;
- invoking configured tools.

Requirements:
- server-side permissions always win;
- structured actions must validate before execution;
- sensitive/irreversible actions may require approval according to configuration;
- AI failure must not corrupt domain state;
- useful audit trail should exist for significant actions.

### 5.12 Integrations

Initial/likely channels include messaging platforms such as WhatsApp, with email/SMS/other channels possible later.

Integration design must support:
- inbound webhooks;
- outbound messages;
- media/attachments;
- delivery status;
- provider identity mapping;
- retry/rate-limit handling;
- idempotency;
- credential/configuration isolation per account/channel.

Provider-specific behavior must not leak throughout core domain code.

### 5.13 Search

Search should optimize operator retrieval of actionable records.

Start with database-backed search for customer/conversation/message metadata where feasible before adding external search infrastructure.

Search must respect tenant and authorization boundaries.

### 5.14 Audit/history

The product should preserve enough history to answer operational questions such as:
- who owned this conversation and when?;
- who changed state?;
- who created/rescheduled/cancelled the booking?;
- which AI/human agent sent this message?;
- what key qualification changed?;

Do not create a generic event-sourcing architecture solely to achieve auditability.

---

## 6. Non-functional requirements

### 6.1 Simplicity

A new engineer or capable AI agent should be able to trace a feature through the monolith without learning an internal framework first.

### 6.2 Reliability

Critical operations such as message ingestion, assignment, and booking must tolerate retries/concurrency without duplicating or corrupting state.

### 6.3 Performance

Common screens should remain responsive for realistic service-business/team usage.

Optimize measured bottlenecks. Avoid premature distributed caching/search/event infrastructure.

### 6.4 Security

Requirements include:
- strict tenant isolation;
- server-side authorization;
- safe authentication/session handling;
- webhook signature verification where supported;
- secret protection;
- attachment validation;
- protection against common web vulnerabilities;
- least privilege for AI/tools/integrations.

### 6.5 Observability

Operational failures should be diagnosable.

Important external interactions/jobs should expose enough structured logging/correlation to trace:
- account/channel;
- conversation;
- job/request;
- provider event/message ID;
- normalized outcome.

Avoid leaking secrets or unnecessary sensitive customer data in logs.

### 6.6 International/timezone readiness

The product is intended for service businesses worldwide.

Therefore:
- timestamps are stored consistently;
- display uses relevant user/account timezone;
- phone numbers and locale/language should not assume one country;
- text/UX should remain translatable;
- channel identities should be normalized carefully.

---

## 7. Deliberate non-goals for the initial architecture

Unless a concrete requirement changes this, Reservi is not trying to become:

- a Salesforce clone;
- a general BPM/workflow engine;
- a no-code database builder;
- an event-sourced platform;
- a microservice mesh;
- a generic omnichannel marketing automation suite;
- a BI/data warehouse;
- a full accounting/invoicing platform;
- a generic project-management system.

Features may be added later, but they must serve the central conversation-to-service loop rather than dilute it.

---

## 8. Product success criteria

The product is moving in the right direction when:

- operators can understand what needs attention from the inbox quickly;
- a new inbound customer can reach the right agent with minimal manual sorting;
- agents can qualify and book from one conversation context;
- ownership is always clear;
- AI can perform useful work without bypassing product truth;
- the same architecture works for one provider and many teams;
- adding a feature does not require duplicating frontend/backend/domain logic;
- CRM data becomes more accurate because it is produced by the workflow itself;
- system complexity grows slower than product capability.

---

## 9. Feature acceptance template

Before implementing a feature, express it as:

```text
Actor:
Trigger:
Preconditions:
Expected user-visible result:
Persisted truth:
Side effects:
Authorization:
Invariants affected:
Failure/retry behavior:
Test/verification plan:
```

A feature should not be considered complete until these expectations are proven at the appropriate levels.
