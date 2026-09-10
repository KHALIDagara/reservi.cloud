---
name: reservi-context
description: Load the durable product, architecture, domain, invariants, and engineering context for Reservi before any meaningful design or implementation work.
---

# Reservi Context

Load this skill before any non-trivial Reservi task.

## Read order

Start with the closest `AGENTS.md`, then read only the relevant durable docs:

1. `docs/product-requirements.md` — product purpose, users, workflows, scope, non-goals.
2. `docs/architecture.md` — system shape, boundaries, technical principles.
3. `docs/domain-model.md` — domain concepts and relationships.
4. `docs/invariants.md` — truths that must never be broken.
5. `docs/testing.md` — proof strategy and completion standards.

Use `docs/README.md` as an index when uncertain.

## Core mental model

Reservi is a mobile-first, conversation-centric CRM and service-operations system for service businesses and agencies.

The operating loop is:

INCOMING CONVERSATION
-> identify/resolve customer
-> capture intent and qualification
-> route to the right team/agent/location
-> collaborate through the same conversation
-> schedule service as quickly as possible
-> perform/complete the service
-> retain truthful history/context automatically

A lead is literally a conversation. The conversation is the central operational object.

Do not recreate traditional CRM abstractions (`Lead`, `Opportunity`, `Deal`, generic `Activity`) merely because other CRMs have them. Introduce a new durable concept only when it has its own lifecycle, truth, and behavior that cannot be expressed coherently through existing concepts.

Humans and AI use the same conceptual `Agent` abstraction. They may differ by capabilities, permissions, runtime/instructions, or presence, but should not become two parallel operational architectures.

Teams group agents and participate in routing. A conversation normally has one current owner at a time while retaining assignment history.

Bookings are operational commitments attached to the customer/conversation context, not a detached calendar product.

The CRM should maintain itself as a side effect of useful operational work. Avoid forcing staff to update redundant records just to keep a pipeline tidy.

## Product north star

Optimize the whole system for one practical outcome:

**Turn a customer message into correctly understood, correctly routed, scheduled, and completed work with as little friction and bookkeeping as possible.**

The product must work for:

- an individual service provider;
- a local service business with several operators;
- an agency distributing leads across multiple locations/service providers;
- teams where AI and humans collaborate;
- tens of agents/teams without changing the core mental model.

## Engineering north star

ONE ENGINE, ONE GOAL.

Prefer a compact Rails monolith whose frontend and backend share the same domain and rendering model. Prefer boring, mature primitives over distributed architecture.

Default preferences:

- Ruby on Rails monolith.
- PostgreSQL as source of durable truth.
- Hotwire: Turbo + Stimulus for the web UI.
- HTML/server state before client-side state.
- Active Job for asynchronous work; choose a concrete backend only when deployment needs it.
- Active Storage for managed attachments where appropriate.
- REST/resourceful routes before custom RPC endpoints.
- Database constraints + application validations for real invariants.
- Explicit integration adapters for WhatsApp/email/SMS/AI/provider APIs.

Avoid by default:

- microservices;
- separate SPA unless a concrete need justifies it;
- GraphQL as an internal default;
- CQRS/event sourcing;
- repository/DTO/command-bus layers;
- service-object explosion;
- speculative plugin frameworks;
- duplicating provider state in the core domain;
- adding abstractions for imagined future scale.

## Decision heuristics

Before creating a model/table/class/service, ask:

1. Is this a real domain concept or merely an implementation step?
2. Does it have an independent lifecycle?
3. Does it own durable truth?
4. Can it be an attribute, association, value object, scope, or derived value instead?
5. Are we duplicating existing state?
6. Does the abstraction make common changes easier or harder?
7. Would a new engineer understand it without a diagram?

Before adding infrastructure, ask:

1. What current failure does this solve?
2. Could Rails/PostgreSQL already solve it?
3. Does it create a second source of truth?
4. Is the operational burden justified today?

## Context discipline

Checked-in code and docs beat remembered discussion. If reality differs from these documents, surface the mismatch. Update durable docs only when the durable decision itself changes.
