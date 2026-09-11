---
name: testing
description: "Apply Reservi's testing doctrine: prove Flow/Stage behavior, domain rules, HTTP/integration behavior, asynchronous work, critical browser flows, tenant isolation, idempotency, and concurrency."
---

# Testing Reservi

Read `docs/testing.md` and `docs/invariants.md` before meaningful coverage. Load `flow-engine` when Flow/Stage/Rule/Field/Catalog/Item/Appointment behavior is involved.

## Principle

Tests are executable statements of product truth. Optimize for confidence, not line coverage.

Use the lowest useful layer, then add higher-level proof where boundaries matter.

## Preferred layers

### Predicate/domain tests
Use for:
- structured predicate evaluation;
- Stage completion;
- Field validation;
- Catalog/Item/ItemSelection behavior;
- Appointment behavior;
- assignment rules;
- permissions/capabilities;
- derived state.

### Flow runtime tests
Use for:
- Rule matching;
- Action execution;
- Action idempotency;
- Stage completion/advancement;
- loop protection;
- stable configured references;
- configuration edge cases.

### Request/integration tests
Use for:
- tenant scoping;
- authorization;
- HTTP/configuration contracts;
- webhooks;
- provider/API boundaries;
- Turbo responses where behavior depends on them.

### Job tests
Use for retries, idempotency, asynchronous side effects, external-provider coordination, AI work, and deferred Rule Actions.

### System/browser tests
Use for critical journeys:
- inbox -> Conversation -> reply;
- Stage requirements/progression;
- Catalog Item selection;
- assign/reassign;
- Appointment create/reschedule/cancel;
- human/AI handoff;
- mobile-first interactions.

## Architecture regression scenarios

When Flow architecture is affected, preserve these scenarios:

```text
Appointment without Catalog/Item
Item selection without Appointment
Appointment before Item selection
Item selection before Appointment
multiple Item selectors with stable keys
multiple Appointments with stable roles
Services/Cars/Properties through one Catalog/Item path
no global Item bookable flag required
```

These are intentional architecture tests.

## Mandatory risk cases

When relevant cover:

- another Account cannot read/write/configure references to this record;
- duplicate webhook delivery is safe;
- repeated Rule evaluation does not duplicate irreversible Actions;
- retries do not duplicate Messages/Appointments/Actions;
- concurrent Stage completion advances once;
- concurrent assignment remains truthful;
- explicitly defined Appointment conflicts survive concurrency;
- unauthorized Agents cannot perform privileged actions;
- active configuration changes behave according to defined policy;
- archived/changed selected Items do not silently corrupt process truth;
- provider failures do not leave impossible local state.

Do not invent Item reservation/conflict semantics simply because an Item is a car/room/service. Item selection is not reservation.

## Test quality rules

- Test behavior, not implementation trivia.
- Avoid pinning internal method call sequences unless they are contracts.
- Prefer fixtures/factories that reveal business intent.
- Keep system tests few but valuable.
- Mock remote boundaries, not the domain itself.
- Bugs normally gain regression tests.
- Never weaken a valid test merely to make a change pass.

## Execution order

1. smallest focused test;
2. surrounding file/module;
3. relevant subsystem suite;
4. relevant system/browser proof;
5. concurrency proof where required;
6. broader/full suite for high-risk integration/release work when practical.

Always report exactly what ran and what did not.
