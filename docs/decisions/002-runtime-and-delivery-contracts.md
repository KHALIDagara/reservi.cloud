# ADR-002: Versioned process definitions and recoverable domain operations

Status: accepted as implementation target; not implemented
Date: 2026-09-11

## Context

ADR-001 establishes the correct ontology but does not settle publication, field storage, rule firing, transactional delivery, lifecycle, and concurrency semantics. The [gap audit](../gap-audit.md) found that independent implementers could satisfy the prose while producing incompatible behavior.

The repository is specifications only. These decisions make its first build concrete without inventing a migration from an existing application.

## Decision

1. Keep Rails/PostgreSQL/Hotwire. Use explicit relational models for domain identities and validated JSON only for dynamic values/configuration.
2. Publish immutable FlowVersions and pin each Conversation. Use ordered Stages, one current stage, no implicit live migration or reverse progression.
3. Separate active/completed/cancelled process state from attention/read state and timed Appointment lifecycle. Completion is the configured outcome, not universally service delivery.
4. Use one typed predicate AST with explicit missing/unknown semantics and one explanation tree for humans/AI.
5. Rules execute once per stage entry in deterministic order. A local rule bundle and its idempotency record commit atomically; external work is durable intent reconciled later.
6. Recover lost enqueue from persisted pending revisions, WebhookReceipt rows, Message rows and AiRun state. Do not assume after-commit enqueue and database commit are atomic.
7. Reconcile ambiguous provider sends; never promise exactly-once remote delivery or blindly repeat an unknown send without provider support.
8. Snapshot selected listing context. Catalog edits do not silently change a request's selected price or predicate attributes.
9. Appointments remain item-independent. Initially constrain one optional scheduled Agent per Appointment using database interval exclusion; no inventory/item availability.
10. Enforce Account relationships in the database and same-account visibility/capabilities in policies. Rules use explicit automation authority; AI output is revision- and ownership-checked.
11. Implement and prove human operations before Rules/provider adapters/AI. Use the dependency plan and evidence ledger.

## Consequences

Published version retention, RuleExecution, WebhookReceipt and AiRun introduce support records, each justified by a specific correctness/recovery need. Snapshot selection requires an explicit refresh when the operator wants current listing values. Shared Customer facts require fan-out and short Customer-before-Conversation locking, which can serialize simultaneous requests for the same customer; measure this before seeking a more complex design.

Once-per-entry Rules prioritize predictability over continuously enforcing a desired value. Manual changes persist after a Rule fired. Later unfired Rules can still act according to configuration. Rule authors see execution order and history.

Account-local Agent calendar exclusivity does not reserve a car/room/property or prevent the same human being booked in a different tenant. These limitations are explicit rather than hidden scheduling promises.

## Alternatives considered

- Mutable published definitions: rejected because new edits silently reinterpret in-flight requests.
- Universal field/value/entity database: rejected because it obscures known relational integrity.
- Snapshot nothing: rejected because selected prices/attributes participate in durable decisions.
- Generic event bus/event sourcing/outbox framework: not needed for the first build; domain records plus sweeps provide recoverable work. Revisit only for a concrete effect not represented by existing durable work.
- Rules firing on every evaluation: rejected because repeated messaging and routing fights are unacceptable.
- Assuming remote exactly-once: rejected because provider acceptance and local commit cannot be one transaction.
- Full item reservation/multi-participant scheduler: deferred per product scope.

## Verification

[Testing strategy](../testing.md) names failure/race scenarios. [Implementation plan](../implementation-plan.md) connects them to task acceptance gates. Decisions are not verified until the ledger contains real implementation evidence.
