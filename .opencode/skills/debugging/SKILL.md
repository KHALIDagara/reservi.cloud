---
name: debugging
description: Diagnose and fix Reservi bugs with a deterministic reproduce-isolate-hypothesize-fix-verify workflow instead of trial-and-error edits.
---

# Debugging Reservi

Use this for defects, failing tests, production errors, flaky behavior, race conditions, integration failures, and unexplained state.

Load `flow-engine` when the defect touches Stage progression, Rules, Fields, Catalog/Items, ItemSelection, Appointment, routing, or assignment automation.

## Procedure

1. REPRODUCE — obtain the smallest reliable failing scenario.
2. OBSERVE — collect exact error, inputs, state, configuration version, logs, request/job identity, and timing.
3. TRACE — follow the real path through request/domain/Flow/integration boundaries.
4. ISOLATE — reduce plausible causes.
5. HYPOTHESIZE — state one concrete cause that predicts the behavior.
6. TEST — run the smallest experiment that can falsify it.
7. FIX ROOT CAUSE — repair the broken assumption/invariant, not only the symptom.
8. REGRESSION TEST — encode the failing scenario at the lowest useful layer.
9. VERIFY — rerun original reproduction plus surrounding tests/browser flow.
10. REVIEW — inspect final diff for collateral changes.

## Evidence hierarchy

Prefer:
- reproducible tests;
- logs/traces;
- database state/constraints;
- actual request/job/configuration data;
- Rule/Action execution history;
- git history/blame when behavior changed;
- provider docs/recorded responses at integration boundaries.

Do not guess when the code/state can be traced.

## Common Reservi bug classes

Actively check for:

- missing Account scope;
- invalid cross-Account configured reference;
- duplicate webhook delivery;
- non-idempotent jobs or Rule Actions;
- repeated Rule evaluation sending/creating twice;
- two evaluators advancing one Stage twice;
- Rule/action loops;
- stale configuration or changed Stage semantics;
- unstable label used as logic identity instead of stable key;
- race between assignments;
- explicitly constrained Appointment overlap;
- Appointment accidentally requiring Item/Service/bookable semantics;
- Item selection accidentally treated as reservation;
- stale Turbo/browser state;
- callbacks hiding Flow side effects;
- provider status treated as local domain truth;
- retries duplicating customer-visible Messages;
- partial local transaction followed by external failure;
- authorization checked only in UI.

## Architectural regression suspicion

If a bug exists only for `Services`, `Cars`, `Rooms`, `Properties`, etc., first check whether vertical-specific code was introduced where Catalog/Item should share one path.

If an Appointment cannot exist because no Item/Service is selected, treat that as an architectural regression unless current durable requirements explicitly changed.

## Forbidden shortcuts

Do not:

- make random edits until tests pass;
- add broad rescue to hide failure;
- disable valid constraints;
- add arbitrary sleeps/timeouts for races;
- delete valid failing tests;
- rewrite an area before understanding it;
- blame dependency/provider without evidence.

When cause remains uncertain, report evidence and remaining hypotheses rather than a guess.
