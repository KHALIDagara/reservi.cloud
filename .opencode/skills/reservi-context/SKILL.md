---
name: reservi-context
description: Load the durable product, flow, architecture, domain, invariants, and engineering context for Reservi before meaningful design or implementation work.
---

# Reservi Context

Load this skill before any non-trivial Reservi task.

## Read order

Start with the closest `AGENTS.md`, then read only relevant durable docs:

1. `docs/product-requirements.md` — product purpose and behavior.
2. `docs/flow-engine.md` — canonical Stage/Rule/Field/Catalog/Item/Appointment composition model.
3. `docs/architecture.md` — system shape and technical boundaries.
4. `docs/domain-model.md` — durable concepts and relationships.
5. `docs/invariants.md` — truths that cannot be broken.
6. `docs/testing.md` — proof strategy.

Use `docs/README.md` as an index when uncertain.

## Canonical mental model

Reservi is a mobile-first, conversation-centric CRM and operations system.

A lead is the Conversation.

The Conversation is also the running process instance.

```text
Conversation state
      ↓
Current Stage
      ↓
Humans + AI + Rules change state
      ↓
Stage completion predicate becomes true
      ↓
Next Stage
```

A Stage is not a status label:

```text
Stage = Blocks + Rules + Completion Predicate
```

A Rule is:

```text
Rule = Predicate + Actions
```

The extension contract is:

```text
Feature = State + Controls + Predicates + Actions
```

## Three questions that prevent most bad modeling

Before adding a business concept, ask:

1. Is it a fact about Customer/request? -> `Field`.
2. Is it a reusable selectable business thing? -> `Catalog` + `Item`.
3. Is it a time-bound commitment? -> `Appointment`.

Create another first-class concept only if it owns a real independent lifecycle/invariant that these primitives cannot express coherently.

## Catalog / Item rule

Services, cars, rooms, properties, treatments, packages, products, and similar things are not separate Flow primitives.

They are Catalog Items.

Examples:

```text
Catalog: Services   -> Item: Garden Maintenance
Catalog: Cars       -> Item: Range Rover Evoque
Catalog: Properties -> Item: Villa Agdal
```

Item base shape:

- title;
- images;
- description;
- price;
- typed additional attributes;
- lifecycle state.

Do not introduce separate `Service`, `Resource`, `ResourceType`, `Car`, `Room`, or `Property` workflow abstractions when Catalog/Item is sufficient.

A configured Catalog Selector places Item selection into Conversation state under a stable role key.

Selection means selection only. It does not inherently mean booked, reserved, exclusive, owned, or scheduled.

## Appointment rule

`Appointment` is the canonical scheduling entity.

It is a time-bound commitment associated with the Conversation and is independent from Catalog Item selection.

Never assume:

- Appointment requires Service;
- Appointment requires Item;
- Item requires Appointment;
- Item needs a `bookable` flag;
- Item selection must happen before Appointment.

All of these are valid:

```text
Appointment without Item
Item without Appointment
Appointment before Item
Item before Appointment
multiple Items
multiple Appointments
no Catalog at all
```

If a Conversation selected `Range Rover Evoque` and later has a `Pickup` Appointment, an operator understands the relation from the shared Conversation context. The core app does not need to infer that the Item is bookable.

Do not add item-level reservation/capacity semantics until a real requirement requires them.

## Human / AI symmetry

Humans and AI share the conceptual `Agent` abstraction.

They operate against the same current Stage, Fields, ItemSelections, Appointments, ownership, Messages, and rules, subject to capabilities.

Do not put the authoritative business flow only in an AI prompt. Flow configuration is authoritative; prompts help AI operate inside it.

## Product north star

Optimize for:

> Move a customer Conversation through the business to its intended outcome with the least friction and bookkeeping while preserving truthful operational state.

The product should work for individual providers, teams, agencies, rentals, property operations, service businesses, and future verticals through configuration rather than parallel architectures.

## Engineering north star

**ONE ENGINE, ONE GOAL.**

Prefer:

- Rails monolith;
- PostgreSQL;
- Turbo + Stimulus;
- server-rendered truth;
- Active Job;
- explicit integration adapters;
- database constraints for real invariants;
- small deterministic Flow runtime.

Avoid by default:

- microservices;
- separate SPA;
- CQRS/event sourcing;
- repository/DTO/command-bus layers;
- service-object explosion;
- generic BPM engines;
- arbitrary scripting in Rules;
- universal Entity/Property/Relation schema;
- vertical-specific workflow engines;
- abstractions for imagined future scale.

## Decision heuristics

Before creating a model/table/class/service ask:

1. Is this a real domain concept or just an implementation step?
2. Can Field express it?
3. Can Catalog/Item express it?
4. Can Appointment express it?
5. Does it have an independent lifecycle/invariant?
6. Does it duplicate current Conversation state?
7. Can it integrate through State + Controls + Predicates + Actions?
8. Would a new engineer understand it without learning an internal framework?

Before infrastructure ask:

1. What current failure does this solve?
2. Can Rails/PostgreSQL solve it?
3. Does it create a second source of truth?
4. Is the operational burden justified now?

## Context discipline

Checked-in code/docs beat remembered discussion.

If reality differs from docs, surface the mismatch. Update durable docs only when durable truth changes.
