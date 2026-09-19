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
- mobile-first interactions;
- collaborative inbox realtime behavior across two sessions;
- message-window pagination/scroll preservation;
- viewer-specific unread updates;
- stage-panel morph after field/item/appointment changes;
- attachment/audio composer behavior when supported.

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


## CI integrity — mandatory

The verification command's real exit status is part of the evidence.

Forbidden:

- excluding known failing tests from the normal suite merely to make CI green;
- shell wrappers that run tests under `... || { ...; exit 0; }`;
- suppressing a non-zero test exit code;
- reporting "0 failures" when the underlying command failed;
- weakening/deleting valid assertions instead of fixing the defect.

If a failure is genuinely pre-existing or infrastructure-related, keep it visible, report it precisely, and triage it separately. Do not counterfeit a green suite.

## Collaborative inbox proof matrix

When `hotwire-inbox` applies, prove as relevant:

1. inbox route renders workspace, settings are separate;
2. cross-inbox nested Conversation access is rejected;
3. 25-row list uses bounded/query-efficient projection and keyset pagination;
4. latest message window is bounded and chronological;
5. before-window prepends older messages without deleting current messages and preserves visual scroll;
6. after/reconnect window is bounded;
7. opening Conversation updates this agent's read cursor/unread badge without changing another agent's unread state;
8. one send creates exactly one Message and one delivery intent; retry does not duplicate it;
9. attachment belongs to the same Message that delivery references;
10. provider media behavior matches what composer UI offers;
11. selected Conversation receives a realtime message in a second browser/session without reload;
12. list row updates/reorders without full-list refresh;
13. no per-row/message/block subscriptions;
14. field update may advance Stage and panel renders the new current Stage;
15. Catalog picker is conversation/role aware;
16. Appointment picker is conversation/role aware and follows agent -> day -> slot -> confirm;
17. assignment excludes non-assignable AI and remains live for collaborative viewers;
18. mobile work-panel/dialog focus/escape/inert behavior works.

A unit test of a broadcast helper alone does not prove browser subscription compatibility.

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
