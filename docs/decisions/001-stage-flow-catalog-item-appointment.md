# ADR-001: Conversation Stage Flow with Catalog Items and Independent Appointments

Status: accepted
Date: 2026-09-11

## Context

Reservi needs to support many kinds of businesses without creating separate application architectures for each vertical.

Early product thinking naturally described flows such as:

```text
qualification -> service selection -> booking
```

and considered Services and schedulable Resources (cars, rooms, properties, etc.) as distinct domain concepts.

That shape is too opinionated.

Real businesses need combinations such as:

```text
appointment -> qualification
vehicle selection -> appointment
appointment -> package selection
property selection with no appointment
appointment with no service or item
```

The product also needs humans and AI to share one deterministic understanding of what a Conversation needs next.

We want high configurability without turning Reservi into a generic BPM engine, Airtable-like universal schema, or vertical-specific codebase.

## Decision

### 1. Conversation is the process instance

A lead is the Conversation.

Conversation is the operational root whose normalized state includes current Stage, Fields, Item selections, ownership, Appointments, Messages, and other feature state.

### 2. Flow is an ordered set of Stages

The initial Flow model is deliberately sequential rather than an arbitrary graph.

A Stage is an executable desired-state contract:

```text
Stage = Blocks + Rules + Completion Predicate
```

A Stage advances when its completion predicate is true against authoritative server state.

### 3. One predicate/action model

Rules are:

```text
Rule = Predicate + Actions
```

The same structured predicate model is used for Stage completion, routing/assignment, messaging conditions, and other supported conditional behavior.

Rules call normal protected domain operations.

### 4. Fields represent facts

Configurable facts about a Customer or Conversation/request are Fields.

Examples: name, city, budget, surface, urgency.

### 5. Catalog + Item represents reusable selectable business things

Services, cars, rooms, properties, treatments, packages, products, equipment-like offerings, and similar selectable business objects share one core abstraction:

```text
Catalog
└── Item
```

An Item has a common shape such as:

- title;
- images;
- description;
- price;
- typed additional attributes;
- lifecycle state.

Different business nouns are represented by different Catalogs and attributes, not by different Flow engines or subtype trees.

A configured Catalog Selector creates an ItemSelection in Conversation state under a stable role key.

Selection means selection only. It does not imply reservation, scheduling, exclusivity, or ownership.

### 6. Appointment is independent scheduling state

Appointment is the canonical time-bound commitment associated with a Conversation.

Appointment does not globally require:

- Service;
- Catalog Item;
- Resource;
- Item `bookable` flag.

Item selection and Appointment may occur in either order or independently.

When a Conversation contains a selected `Range Rover Evoque` Item and later a `Pickup` Appointment, the operator sees both through shared Conversation context and understands the business relationship. Reservi does not need to classify the Item as bookable to make the workflow valid.

If explicit item-level inventory reservation/capacity becomes a proven future requirement, it will be introduced deliberately as its own scheduling/reservation semantics rather than silently baked into all Items.

### 7. Future features integrate through a common contract

A new first-class feature should integrate through:

```text
Feature = State + Controls + Predicates + Actions
```

This lets Stages compose new capabilities without adding feature-specific transition logic to the central Flow engine.

## Consequences

### Positive

- One mental model can serve service businesses, rentals, property operations, salons, agencies, and future verticals.
- Service is no longer architecturally privileged.
- Appointment can appear at any Stage and can exist with no selected Item.
- Cars/rooms/properties/services share one reusable presentation/selection model.
- Humans and AI can read the same Stage requirements and Conversation state.
- Routing/assignment becomes an ordinary Rule Action instead of a parallel automation engine.
- The core Flow runtime stays small and deterministic.
- New features can compose into Flow without rewriting the engine.

### Costs / risks

- Configurable predicates/actions require careful validation, stable keys, idempotency, and explainability.
- Active Flow/Catalog configuration changes need defined semantics for in-flight Conversations.
- Item attribute definitions need enough typing/validation to support Rules safely.
- Catalog/Item must not become a universal meta-object that replaces genuinely distinct domain concepts.
- If inventory reservation/capacity later becomes required, it needs explicit design rather than being assumed from Item selection.

## Alternatives considered

### Hard-coded qualification -> service -> booking pipeline

Rejected because it forces one service-business workflow and makes Appointment depend on Service ordering.

### Separate Service, Car, Room, Property, Resource models

Rejected as the default because these concepts share the same reusable selection/presentation needs and would push vertical vocabulary into the core Flow architecture.

A future concept may still earn its own model if it develops an independent lifecycle/invariant that Catalog/Item cannot express.

### Generic Resource / ResourceType abstraction

Superseded by Catalog / Item for reusable selectable business objects. Catalog/Item better matches the product's need for rich title/images/description/price/attributes and avoids implying scheduling semantics.

### Generic workflow graph / BPM engine

Rejected for initial architecture. Ordered Stages + structured Rules + completion predicates provide substantial flexibility with far less complexity.

### Universal Entity / Property / Relation metadata system

Rejected because it erases domain meaning and would turn Reservi into a generic database-builder framework.

## Guardrails

Future changes should preserve explicit tests for:

- Appointment without Item selection;
- Item selection without Appointment;
- Appointment before Item selection;
- Item selection before Appointment;
- multiple Item selectors;
- multiple Appointments;
- Services/Cars/Properties using the same Catalog/Item path;
- no global `bookable` flag required;
- repeated Rule evaluation not duplicating irreversible Actions;
- concurrent Stage completion advancing once.
