---
name: repository-navigation
description: Inspect and trace the Reservi repository before editing so agents reuse existing behavior, tests, and patterns instead of inventing parallel implementations.
---

# Repository Navigation

Use this before implementing in an existing code area.

## First pass

1. `git status` — protect unrelated local work.
2. Inspect the relevant tree, not the whole repository blindly.
3. Search for the domain noun and the user-visible action.
4. Locate existing tests before changing behavior.
5. Trace the complete path relevant to the request.

Typical trace:

```text
route
→ controller/request
→ authorization/account scope
→ model/domain operation
→ schema/index/constraint
→ job/integration
→ view/Turbo/Stimulus
→ tests
```

## Search strategy

Search concepts before class names.

For a task such as "reassign a conversation", inspect:
- `Conversation`;
- assignment/owner fields and methods;
- Team/Agent relations;
- routes/controllers that already mutate assignment;
- history records;
- authorization;
- tests;
- Turbo fragments/broadcasts that display owner.

Use git history/blame only when current behavior or rationale is unclear; do not cargo-cult old implementations merely because they existed.

## Reuse test

Before introducing a new class/table/abstraction ask:

- Is there already a concept that owns this behavior?
- Is there an existing operation/pattern for a similar transition?
- Can the change extend that path without making it incoherent?
- Am I about to create a second source of truth?

## Avoid false archaeology

Do not spend excessive time exploring unrelated code. Once the relevant path and invariants are understood, proceed with the smallest plan.

## Before completion

Re-run searches for the old concept/name when a refactor removes/replaces behavior. Check that routes, tests, views, jobs, and docs did not retain stale references.
