# Reservi Documentation Index

This directory contains durable project truth for humans and AI agents.

Read documents by purpose rather than loading everything for every task.

## Build status and starting point

At the audited baseline `153315d`, this repository contains specifications and agent configuration, not a running Rails application.

- [Gap audit](gap-audit.md): 55 gaps/boundaries, priorities, decisions, and task mapping.
- [Implementation plan](implementation-plan.md): dependency graph, task acceptance gates, and evidence ledger. Start here when deciding what to implement next.
- [ADR-002](decisions/002-runtime-and-delivery-contracts.md): concrete runtime/persistence/recovery decisions building on ADR-001.

Do not treat a specification decision as a verified implementation.

## Core documents

### `product-requirements.md`

Read when deciding **what Reservi should do**.

Defines:
- product purpose;
- configurable Stage experience;
- Fields;
- Catalogs / Items;
- Appointments;
- human/AI operation;
- product boundaries and success criteria.

### `flow-engine.md`

Read before any work involving **Flow, Stage, Rule, Field, Catalog, Item, ItemSelection, Appointment, routing, assignment automation, or AI progression**.

This is the canonical composition model:

```text
Conversation = State + Current Stage
Stage = Blocks + Rules + Completion Predicate
Rule = Predicate + Actions
Feature = State + Controls + Predicates + Actions
```

It also establishes the crucial distinctions:

```text
fact -> Field
reusable selectable business thing -> Catalog Item
time-bound commitment -> Appointment
```

and explicitly forbids a mandatory Service -> Appointment path or global Item `bookable` assumption.

### `architecture.md`

Read when deciding **how the system should be shaped**.

Contains:
- Rails monolith posture;
- Flow runtime boundaries;
- predicate/action architecture;
- multi-tenancy;
- Catalog/Item architecture;
- Appointment independence;
- jobs/idempotency/concurrency;
- realtime/security/scaling principles;
- architectural anti-patterns.

### `domain-model.md`

Read when deciding **which durable concepts should exist and what they mean**.

Canonical concepts include:
- Account;
- User;
- Agent;
- Team;
- Customer;
- Channel/Integration;
- Conversation;
- Flow / Stage / Rule;
- Field Definition / Value;
- Catalog / Item / ItemSelection;
- Appointment;
- Message / Note;
- Assignment.

### `invariants.md`

Read before changes that can affect correctness.

Contains hard truths for:
- tenant isolation;
- Conversation/Stage truth;
- Rule/Action idempotency;
- Field scope/validation;
- Catalog/Item semantics;
- Appointment independence;
- assignment/AI authority;
- messaging/integration safety;
- UI/server truth;
- simplicity/extensibility.

### `testing.md`

Read before designing verification or fixing a bug.

Contains:
- predicate/domain testing;
- Flow runtime proof;
- configuration-composition scenarios;
- browser/mobile journeys;
- concurrency/idempotency tests;
- provider/AI testing;
- definition of verified.

## Agent instructions

Repository-wide AI behavior is defined in root `AGENTS.md`.

OpenCode configuration lives in:

```text
opencode.jsonc
.opencode/agents/
.opencode/skills/
```

The default primary OpenCode agent is `reservi`.

For Flow-related work the agent should load the `flow-engine` skill.

## Source-of-truth order

When information conflicts:

1. explicit current product requirement / hard invariant;
2. current working code and database behavior;
3. current durable docs;
4. tests, after checking whether they are stale;
5. old commits/discussions as historical evidence only.

Do not silently choose when code/docs conflict. Determine what is stale and correct it deliberately.

## Documentation rule

These files are not a changelog.

Update them only when durable product/domain/architecture/invariant/testing truth changes.

For decisions whose historical rationale matters, create an ADR under `docs/decisions/`:

```text
# ADR-NNN: Decision title

Status: accepted | superseded | deprecated
Date: YYYY-MM-DD

## Context
## Decision
## Consequences
## Alternatives considered
```
