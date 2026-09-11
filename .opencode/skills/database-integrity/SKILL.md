---
name: database-integrity
description: Design Reservi PostgreSQL schema, constraints, indexes, transactions, locking, migrations, and query paths so durable business truth survives concurrency, retries, and configurable Flow execution.
---

# Database Integrity

PostgreSQL is the durable source of truth for Reservi. Application code provides behavior/UX; the database should prevent impossible durable states where practical.

## Schema design

For each persisted concept define:

- Account ownership;
- required foreign keys;
- nullability;
- uniqueness scope;
- lifecycle/archive/deletion behavior;
- stable configured identity/keys where needed;
- expected lookup/order paths;
- timestamps/audit fields where meaningful.

Prefer relational columns for stable known truth. Structured JSONB is acceptable for genuinely configurable validated expression/attribute data, not as a shortcut around known relationships.

For Flow-related persistence explicitly consider:

- one current Stage per Conversation;
- stable Stage/Block/selector keys;
- Account-local Rule references;
- ItemSelection identity/cardinality;
- Rule/Action execution identity for idempotency;
- active configuration version/reference semantics.

## Constraints

Use as appropriate:

- foreign keys;
- NOT NULL;
- unique indexes;
- check constraints;
- exclusion constraints for actual non-overlap rules;
- partial indexes for common scoped subsets.

Application validations provide friendly errors but are not enough for race-sensitive truth.

## Concurrency

Before assignment, Stage advancement, Rule Actions, Appointment scheduling, counters, deduplication, or configuration changes, ask what happens when two requests/jobs execute simultaneously.

Use the smallest correct primitive:

- unique constraint + retry;
- transaction;
- row lock (`with_lock` / `FOR UPDATE`);
- compare-and-set update;
- advisory lock only when row-level primitives cannot express the coordination need.

Important Reservi races include:

- two evaluators advancing the same Stage;
- two executions of one irreversible Rule Action;
- two assignments changing current owner;
- duplicate inbound provider events;
- concurrent Appointment operations for an explicitly constrained participant;
- configuration changed while state is being evaluated.

Do not invent Item-level exclusivity merely because an Item is a car/room/service. ItemSelection is not reservation.

## Idempotency

External events/jobs and irreversible Rule Actions need stable logical identity.

Repeated execution must not duplicate:

- Messages;
- Appointments;
- assignments;
- Rule-triggered external side effects;
- Stage transitions.

Use database uniqueness as the final guard where possible.

## Catalog / Item integrity

Catalogs/Items are Account-owned.

An ItemSelection must not reference an Item from another Account or an Item outside the configured Catalog selector semantics.

Stable selection/Block keys should remain unique in the appropriate Flow/Stage scope.

Item archive/delete behavior must preserve defined semantics for existing selections.

Do not add `bookable` or scheduling columns to Item merely to support generic Appointment behavior.

## Appointment integrity

Appointment is independent from Catalog Item selection.

Do not make `item_id`, `service_id`, or equivalent required by core schema.

Use non-overlap constraints only for scheduling participants the product actually defines as exclusive. Do not automatically make every selected Item participate in time conflicts.

## Migrations

Prefer additive/reversible migrations.

For populated tables:

- avoid long blocking rewrites;
- add nullable/backfill/enforce in stages where needed;
- create indexes safely for deployment environment;
- separate substantial data migrations;
- verify existing data before enforcing new constraints.

Never put remote API calls in migrations.

## Query design

Account scope should be part of indexed access paths where appropriate.

Likely hot lookup dimensions include current Stage, selector keys, Rule/configuration version, ItemSelection, Conversation activity, Appointment time, and owner/team.

Inspect observed SQL/EXPLAIN before adding caches. Eliminate N+1 and add proper indexes before creating a second state system.
