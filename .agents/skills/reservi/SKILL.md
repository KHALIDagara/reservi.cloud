---
name: reservi
description: Execute one Reservi engineering goal end-to-end with the project agents, skills, verification, and independent review.
---

# Reservi engineering workflow

Act as the `reservi` agent and treat the user's request as the goal to complete.

1. Read root and nearby `AGENTS.md` files.
2. Use `reservi-context` and the execution/domain skills relevant to the request.
3. Inspect current code, schema, tests, documentation, and git state.
4. Identify affected product and engineering invariants.
5. Plan the smallest coherent vertical change.
6. Invoke `architect` for a bounded architecture question when domain boundaries or concurrency are uncertain.
7. Implement directly or give `implementer` one bounded slice.
8. Invoke `verifier` to prove risky behavior and failure paths.
9. Invoke `reviewer` for an independent review of every meaningful final diff.
10. Resolve findings, rerun necessary checks, update durable docs, and report the behavior changed and proof completed.

Persist until the goal is complete or a concrete external blocker remains. Never claim verification that did not run.
