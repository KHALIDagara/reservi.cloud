# Reservi Documentation Index

This directory contains durable project truth for humans and AI agents.

Read these documents by purpose rather than loading everything for every task.

## Core documents

### `product-requirements.md`

Read when deciding **what Reservi should do**.

Contains:
- product purpose and north star;
- target users;
- core journeys;
- functional/non-functional requirements;
- deliberate non-goals;
- acceptance template.

### `architecture.md`

Read when deciding **how the system should be shaped**.

Contains:
- Rails monolith posture;
- boundaries;
- multi-tenancy;
- messaging/integration flow;
- jobs/idempotency;
- database/transaction rules;
- realtime/search/security/scaling principles;
- architectural anti-patterns.

### `domain-model.md`

Read when deciding **which durable concepts should exist and what they mean**.

Contains the conceptual model for:
- Account;
- User;
- Agent;
- Team;
- Customer;
- Channel/Integration;
- Conversation;
- Message;
- Note;
- Assignment;
- Qualification;
- Booking;
- scheduling/supporting concepts.

### `invariants.md`

Read before any change that can affect correctness.

Contains hard truths covering:
- tenant isolation;
- conversation/ownership;
- AI authority;
- messaging idempotency;
- booking conflicts;
- database integrity;
- integration safety;
- UI/server truth;
- simplicity.

### `testing.md`

Read before designing verification or fixing a bug.

Contains:
- test-layer strategy;
- mandatory invariant coverage;
- system/browser journeys;
- concurrency testing;
- provider/AI test strategy;
- mobile/security verification;
- definition of verified.

## Agent instructions

Repository-wide agent behavior is defined in root `AGENTS.md`.

OpenCode configuration lives in:

```text
opencode.jsonc
.opencode/agents/
.opencode/skills/
```

The default primary OpenCode agent is `reservi`.

## Source-of-truth order

When information conflicts, do not guess.

Use this resolution process:

1. hard product invariant / explicit user requirement;
2. current working code and database behavior;
3. current durable docs;
4. tests (while checking whether they are stale);
5. old commits/discussions as historical evidence only.

If code and docs disagree, identify which one is stale and correct it deliberately.

## Documentation rule

These files are not a changelog.

Update them only when durable product, domain, architecture, invariant, or testing truth changes.

For important decisions whose rationale/history matters, create an ADR under `docs/decisions/` using a simple structure:

```text
# ADR-NNN: Decision title

Status: accepted | superseded | deprecated
Date: YYYY-MM-DD

## Context
## Decision
## Consequences
## Alternatives considered
```
