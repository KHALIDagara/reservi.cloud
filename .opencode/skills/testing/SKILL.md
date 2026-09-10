---
name: testing
description: Apply Reservi's testing doctrine: prove domain rules, HTTP/integration behavior, asynchronous work, critical browser flows, tenant isolation, idempotency, and concurrency.
---

# Testing Reservi

Read `docs/testing.md` and `docs/invariants.md` before designing meaningful coverage.

## Principle

Tests are executable statements of product truth. Optimize for confidence in behavior, not line coverage.

Use the lowest useful layer, then add higher-level proof where boundaries matter.

## Preferred layers

### Domain/model tests
Use for:
- state transitions;
- validations;
- assignment rules;
- booking rules;
- permissions/capability predicates;
- qualification behavior;
- derived state.

### Request/integration tests
Use for:
- tenant scoping;
- authorization;
- HTTP contracts;
- webhooks;
- API/integration boundaries;
- Turbo responses when behavior depends on them.

### Job tests
Use for:
- retries;
- idempotency;
- asynchronous side effects;
- external-provider coordination.

### System/browser tests
Use for critical user journeys:
- inbox -> conversation -> reply;
- assign/reassign;
- qualify;
- human/AI handoff;
- create/reschedule/cancel booking;
- calendar/inbox synchronization;
- mobile-first navigation and forms.

## Mandatory risk cases

When relevant, cover:
- another tenant cannot read/write the record;
- duplicate webhook delivery is safe;
- retries do not duplicate messages/bookings/actions;
- stale/concurrent updates cannot violate assignment or booking truth;
- unauthorized agents cannot perform privileged actions;
- history records remain truthful after reassignment/state change;
- provider failures do not leave impossible local state.

## Test quality rules

- Test behavior, not implementation trivia.
- Avoid asserting every internal method call.
- Prefer factories/fixtures that reveal intent.
- Keep system tests few but valuable.
- Do not mock the domain itself.
- Mock/stub remote boundaries when appropriate, and keep at least one contract/integration path where feasible.
- A bug fix should normally gain a regression test that fails before the fix.
- Never delete or weaken a valid test just to make a change pass.

## Execution order

1. Run the smallest focused test while iterating.
2. Run the surrounding test file/module.
3. Run the relevant subsystem suite.
4. Run the full suite before high-risk integration/release changes when practical.
5. Run system/browser proof for changed critical flows.

Always report exactly what was run and what was not.
