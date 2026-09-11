---
name: flow-engine
description: Design, implement, or review Reservi Flow, Stage, Rule, Field, Catalog, Item, ItemSelection, and Appointment behavior without introducing vertical-specific or generic-workflow complexity.
---

# Reservi Flow Engine Skill

Use this skill for any task involving:

- Flow / Stage builder;
- Stage completion/progression;
- Rules, predicates, Actions;
- configurable Fields;
- Catalogs / Items / selectors;
- Appointments;
- routing/assignment automation;
- AI acting on current Stage requirements;
- future feature integration into Flow.

Read `docs/flow-engine.md` first, then relevant sections of `docs/domain-model.md`, `docs/invariants.md`, and `docs/testing.md`.

## The model to preserve

```text
Conversation = Authoritative State + Current Stage
Stage = Blocks + Rules + Completion Predicate
Rule = Predicate + Actions
Feature = State + Controls + Predicates + Actions
```

A Stage means:

> What work is available/required now, what Rules should react to state, and what must become true before progression?

Do not reduce Stage to a label.

## Classification heuristic

Before adding a concept:

```text
fact about Customer/request?          -> Field
reusable selectable business thing?  -> Catalog Item
time-bound commitment?                -> Appointment
```

Only introduce another first-class model if it owns a genuine independent lifecycle or invariant.

## Catalog / Item discipline

Use Catalog/Item for reusable selectable business objects regardless of vertical vocabulary.

Examples:

```text
Services -> Garden Maintenance
Cars -> Range Rover Evoque
Properties -> Villa Agdal
Rooms -> Treatment Room 2
```

Items share title, images, description, price, typed attributes, and lifecycle state.

Do not create separate Service/Car/Property/Room/Resource workflow architectures unless a new invariant truly forces it.

ItemSelection places one/many Items into Conversation state under a stable selector key.

Selection does not mean booking/reservation.

## Appointment discipline

Appointment is independent scheduling state.

Never make these global assumptions:

```text
Appointment requires Item
Appointment requires Service
Item requires Appointment
Item must be bookable
Item selected before Appointment
```

An operator understands relationships from shared Conversation context.

Example:

```text
Conversation:
  vehicle = Range Rover Evoque
  appointment("pickup") = tomorrow 14:00
```

The app does not need `Range Rover Evoque.bookable?` to make this useful.

Do not implement item-level inventory reservation until a concrete requirement asks for it.

## Predicate discipline

Use one structured condition language for completion, routing, assignment, messaging, and supported visibility/eligibility behavior.

Predicates read normalized state through stable references:

```text
field("city")
owner
item_selection("vehicle")
appointment("pickup")
```

Do not reference mutable labels as identity.

Do not execute arbitrary Ruby/JavaScript/SQL/user scripts.

## Action discipline

Actions invoke normal protected domain operations.

Examples:

- assign Agent/Team;
- send Message;
- update Field;
- select/clear Item;
- create/update/cancel Appointment.

Rules are not privileged. Tenant scope, authorization, validation, history, concurrency protection, and idempotency still apply.

## Runtime protocol

Conceptually:

```text
persist authorized state mutation
-> evaluate applicable Rules
-> execute newly applicable Actions safely
-> re-read authoritative state
-> evaluate completion predicate
-> if complete, advance exactly once
```

Implementation must address:

- repeated evaluation;
- Action idempotency;
- Rule/action loops;
- concurrent evaluation/advancement;
- stale configuration;
- configuration versioning/edit semantics;
- explainability.

Avoid broad Active Record callback webs. Prefer one explicit Flow evaluation entry point invoked by domain operations after meaningful state change.

## Initial scope constraints

Keep the first Flow system intentionally bounded:

- ordered Stages;
- one current Stage;
- supported Blocks;
- structured Rules;
- one completion expression;
- next Stage progression.

Do not introduce unless required:

- arbitrary graphs;
- parallel stages;
- loops;
- generic timer nodes;
- arbitrary webhooks;
- code/script nodes;
- BPMN semantics.

## Configuration safety

Active Flow/Catalog configuration can affect in-flight Conversations.

Whenever implementing edits, define behavior for:

- Stage rename/reorder/archive;
- Block removed;
- completion expression changed;
- Rule changed;
- Field changed;
- Catalog archived;
- Item archived/changed while selected;
- Agent removed.

Prefer versioning/constrained edits/explicit migration over silent reinterpretation.

## Required architecture regression tests

Protect these scenarios explicitly:

1. Appointment with no Catalog/Item.
2. Item selection with no Appointment.
3. Appointment before Item selection.
4. Item selection before Appointment.
5. Multiple Appointments with stable role keys.
6. Multiple Item selectors with stable role keys.
7. Services, Cars, Properties all use the same Catalog/Item path.
8. Repeated Rule evaluation does not duplicate irreversible Actions.
9. Concurrent completion advances a Stage once.
10. Cross-Account configuration references are rejected.

## Review questions

Before accepting a Flow change ask:

- Did this add a hidden vertical assumption?
- Did this make Service special again?
- Did this make Item selection imply reservation?
- Did this make Appointment require Item/bookability?
- Did this add another condition language?
- Did this add a new concept where Field/Catalog/Appointment already fits?
- Is progression deterministic and explainable?
- Can retries/concurrency violate truth?
- Can humans and AI use the same state?
