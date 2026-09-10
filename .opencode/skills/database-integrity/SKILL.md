---
name: database-integrity
description: Design Reservi PostgreSQL schema, constraints, indexes, transactions, locking, migrations, and query paths so durable business truth survives concurrency and retries.
---

# Database Integrity

PostgreSQL is the durable source of truth for Reservi. Application code provides behavior and UX; the database should prevent impossible durable states where practical.

## Schema design

For each persisted concept define:
- tenant/account ownership;
- required foreign keys;
- nullability;
- uniqueness scope;
- lifecycle/deletion behavior;
- expected lookup/order paths;
- timestamps/audit fields where needed.

Prefer relational columns for stable domain truth. Use JSONB for provider-shaped/flexible metadata, not as a shortcut around modeling known fields.

## Constraints

Use:
- foreign keys;
- NOT NULL;
- unique indexes;
- check constraints;
- exclusion constraints where they genuinely model non-overlap;
- partial indexes for common scoped subsets.

Model validations should provide friendly errors, but they are not enough for race-sensitive truth.

## Concurrency

Before implementing assignment, routing, booking, counters, deduplication, or state transitions, ask what happens if two requests/jobs execute simultaneously.

Use the smallest correct primitive:
- unique constraint + retry;
- transaction;
- row lock (`with_lock`/`FOR UPDATE`);
- compare-and-set style update;
- advisory lock only when row-level primitives cannot express the resource.

Do not rely on `validates_uniqueness_of` for concurrency correctness.

## Idempotency

External events/jobs must have stable deduplication identity whenever the provider offers one.

Record/process events so that repeated delivery does not duplicate:
- messages;
- bookings;
- assignments;
- customer-visible replies;
- billable/irreversible side effects.

## Migrations

Prefer additive/reversible migrations.
For populated tables:
- avoid long blocking rewrites;
- add nullable/backfill/enforce in safe stages when necessary;
- create indexes safely according to deployment environment;
- separate data migrations when they are substantial;
- never assume production data satisfies a new constraint without checking/backfilling.

Do not put remote API calls in database migrations.

## Query design

Tenant scope should normally be part of indexed access paths for large account-owned tables.

Inspect SQL/EXPLAIN for observed slow queries before adding caches. Prefer eliminating N+1 and adding correct indexes before introducing another source of state.
