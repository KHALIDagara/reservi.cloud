---
name: feature-execution
description: Execute a Reservi feature or change from requirement through implementation, verification, review, and documentation without losing architectural coherence.
---

# Feature Execution

Use this skill for any feature, behavior change, refactor tied to a product goal, or cross-cutting engineering task.

## Goal

Deliver the smallest complete vertical slice that advances the product while preserving invariants.

## Workflow

### 1. Understand the request

Translate the request into observable user/system behavior.

Identify:
- actor;
- trigger;
- expected result;
- persisted truth;
- side effects;
- permissions;
- failure behavior;
- acceptance criteria.

Resolve ambiguity by inspecting existing code/docs before inventing behavior.

### 2. Inspect before designing

Trace the current path through:
- routes;
- controllers;
- models;
- queries/scopes;
- jobs;
- views/Turbo/Stimulus;
- integrations;
- tests;
- schema/indexes/constraints.

Reuse existing patterns when they are sound.

### 3. Identify invariants and risks

Read `docs/invariants.md` and list which truths could be affected.

Always consider:
- tenant isolation;
- authorization;
- duplicate external events;
- concurrent assignment/booking updates;
- stale browser state;
- retries;
- partial failure;
- data migration safety.

### 4. Design the smallest coherent change

Prefer a vertical slice through the monolith over a generalized framework.

Avoid introducing a new durable concept unless it has its own lifecycle and truth.

When adding persistence:
- define source of truth;
- define foreign keys;
- add indexes for expected access paths;
- add uniqueness/check constraints for durable invariants;
- define deletion/retention behavior.

When adding asynchronous work:
- make it idempotent;
- define retry behavior;
- avoid making job order an undocumented invariant.

### 5. Define proof before implementation

For each acceptance criterion, decide how it will be proven:
- model/domain test;
- request/integration test;
- job test;
- system/browser test;
- concurrency test;
- manual operational check.

Prefer writing the failing regression/behavior test first for non-trivial logic and bugs.

### 6. Implement in small reversible steps

Keep diffs focused.
Do not refactor unrelated areas.
Do not add dependencies casually.
Keep provider-specific logic at adapters/boundaries.
Prefer Turbo/Stimulus before a client framework.

### 7. Verify

Run focused tests first, then surrounding tests.

For user-visible flows, exercise the actual system/browser path.

Check:
- happy path;
- important failure path;
- authorization/tenant boundary;
- duplicate/retry behavior where relevant;
- mobile interaction where relevant.

### 8. Review independently

Inspect `git diff` completely.
For meaningful changes ask the `reviewer` subagent to review the real diff.
Fix high-confidence findings and re-run relevant verification.

### 9. Update durable context only if truth changed

Update docs when the product model, architecture, invariant, or testing doctrine changed.
Do not turn docs into a changelog.

### 10. Report precisely

State:
- behavior delivered;
- files/areas changed;
- tests and checks actually run;
- unresolved risks/assumptions;
- follow-up work only if truly separate.

## Definition of done

A change is done when:
- requested behavior exists;
- relevant invariants remain true;
- tests cover the meaningful behavior;
- user-visible behavior is exercised where appropriate;
- diff is reviewed;
- docs match durable reality;
- no claim of verification is fabricated.
