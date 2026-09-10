---
name: debugging
description: Diagnose and fix Reservi bugs with a deterministic reproduce-isolate-hypothesize-fix-verify workflow instead of trial-and-error edits.
---

# Debugging Reservi

Use this for defects, failing tests, production errors, flaky behavior, race conditions, integration failures, and unexplained state.

## Procedure

1. REPRODUCE — obtain the smallest reliable failing scenario.
2. OBSERVE — collect exact error, inputs, state, logs, request/job identity, and timing.
3. TRACE — follow the real path through the monolith and integration boundary.
4. ISOLATE — reduce the set of plausible causes.
5. HYPOTHESIZE — state one concrete cause that predicts the observed behavior.
6. TEST — run the smallest experiment that can falsify the hypothesis.
7. FIX ROOT CAUSE — repair the broken assumption or invariant, not merely the symptom.
8. REGRESSION TEST — encode the failing scenario at the lowest useful layer.
9. VERIFY — rerun the original reproduction plus relevant surrounding tests/browser flow.
10. REVIEW — inspect the final diff for collateral changes.

## Evidence hierarchy

Prefer evidence from:
- reproducible tests;
- logs/traces;
- database state and constraints;
- actual request/job payloads;
- git history/blame when behavior changed;
- provider documentation/recorded responses at integration boundaries.

Do not guess from filenames or error text when the code can be traced.

## Common Reservi bug classes

Actively check for:
- missing tenant scope;
- double webhook delivery;
- non-idempotent jobs;
- race between two assignments or bookings;
- stale Turbo/browser state;
- callbacks causing hidden side effects;
- message/provider identifiers not being unique enough;
- time zone conversion errors;
- provider status being treated as local domain truth;
- retries duplicating customer-visible messages;
- partial transaction followed by external failure;
- authorization checked in UI but not server-side.

## Forbidden debugging shortcuts

Do not:
- make random edits until tests pass;
- add broad rescue/`rescue StandardError` to hide failure;
- disable validations or constraints without proving they are wrong;
- increase timeouts/sleeps as the default fix for races;
- delete a failing test that represents valid behavior;
- rewrite an area before understanding why it fails;
- blame a dependency/provider without evidence.

When the cause is still uncertain, report the evidence and remaining hypotheses rather than presenting a guess as a fix.
