# Architecture gap audit

Reviewed: 2026-09-11. Baseline: `153315dac47f6fe0dcc2b6f75d1dfc667bcd175c`.
Historical input: `7f3d533f789cb86e69cdc017b84e58265eb709c7` introduced the original requirements; ADR-001 and the current documents supersede its fixed service/booking assumptions.

## What exists

This repository contains specifications, OpenCode configuration, agents, and skills. It has no Rails application, Gemfile, schema, migrations, executable tests, CI workflow, or deployment configuration. Consequently **none of the behavior below is implemented or verified at runtime**. The architecture describes a build target, not an assessment of production code.

The original documents correctly identify the product primitives. Their main weakness is leaving difficult decisions to whichever agent implements a feature first. “Race-safe”, “versioned where needed”, and “authorized” are intentions; they do not define a transaction, lifecycle, permission rule, or acceptance test.

## Decision register

Priority: P0 blocks a safe foundation; P1 blocks a usable pilot; P2 can wait for evidence. “Specified” means a concrete decision now exists in the linked documents, **not** that the gap has been implemented. Task IDs refer to [implementation-plan.md](implementation-plan.md).

| ID | Priority | Gap / failure scenario | Decision or explicit boundary | Delivery |
|---|---|---|---|---|
| G01 | P0 | Documentation can be mistaken for working software | Record baseline and proof status; bootstrap from scratch, do not invent existing behavior | T00–T01 |
| G02 | P0 | Old commit implies a required service-to-booking sequence | ADR-001 remains authoritative; support single-stage and item-free completion | T04, T07 |
| G03 | P0 | Conversation and Appointment could both become the process state | Conversation owns process; Appointment owns only a timed commitment | T02, T07 |
| G04 | P0 | Inbox closure, stage completion, and appointment completion conflated | Separate attention, process lifecycle, and appointment lifecycle; no automatic regression | T02, T04 |
| G05 | P0 | Repeated customer contact creates or reopens arbitrary requests | Explicit inbound thread resolution and closed-thread behavior; no semantic AI merging | T08 |
| G06 | P0 | Active flow edits silently change requirements | Immutable published FlowVersion; conversation pinned for life; draft/publish validation | T04, T09 |
| G07 | P0 | Deleting/reordering blocks breaks references | Stable keys, typed reference validation, published retention; new versions for structural edits | T04, T09 |
| G08 | P0 | Same selector role means different things in different stages | Role definitions consistent across a version; later blocks may reuse the same role | T05, T07, T09 |
| G09 | P0 | JSON becomes an unvalidated shadow database | Explicit relational identities; bounded, typed JSON only for definitions, expressions, and custom values | T01, T03–T05 |
| G10 | P0 | Required false/zero values are mistaken for missing | Explicit missing/type/boolean/collection semantics and explanation tree | T03–T04 |
| G11 | P0 | Customer field changes affect other active conversations without evaluation | Shared customer lock discipline and durable fan-out reevaluation; completed flows remain completed | T03–T04 |
| G12 | P0 | Labels, phone fields, and provider identities duplicate writable truth | Built-in field bindings; verified channel identity separate from editable profile phone | T02–T03, T08 |
| G13 | P0 | Application tenant filters fail on nested references | Composite tenant foreign keys for relational links; publish and execution checks for JSON references | T01 onward |
| G14 | P0 | Human/AI symmetry accidentally means identical permissions | Actor context plus explicit capabilities, team scope, and current authorization at execution | T01, T06, T10 |
| G15 | P0 | Agency visibility implicitly crosses client tenants | Explicit membership in each Account; teams represent locations inside one Account; no implicit sharing | T01, T06 |
| G16 | P0 | Membership removal leaves authorized stale jobs/subscriptions | Recheck authority; revoke subscriptions; keep historical actors; release owner to queue | T01, T06, T10 |
| G17 | P0 | Two evaluators advance a stage twice | Lock Conversation, unique stage transition identity, expected revision, one evaluator entry point | T04 |
| G18 | P0 | Rules continuously overwrite humans or resend messages | Rule executes once per stage entry; priority/key order; record durable execution identity | T06 |
| G19 | P0 | Multiple actions partly succeed with undefined retry behavior | Atomic local action bundle plus durable outbound Message intent; failure blocks automation visibly | T06, T08 |
| G20 | P0 | Completion skips an action which has failed | Automation errors pause advancement; remote send success is separate from accepted local intent | T06, T08 |
| G21 | P0 | Commit succeeds but enqueue crashes, losing work | Database pending revision / durable message and webhook rows plus recovery sweeps | T04, T08 |
| G22 | P0 | Provider timeout causes duplicate outbound customer messages | Unknown delivery state; reconcile provider identity; no blind resend without deduplication support | T08 |
| G23 | P0 | Duplicate/reordered callbacks regress delivery state | Provider-event uniqueness and adapter-specific monotonic reconciliation | T08 |
| G24 | P0 | Webhook acknowledgment precedes durable acceptance | Authenticate, persist receipt, acknowledge, then process with retries | T08 |
| G25 | P0 | Item price/attribute edits rewrite past decisions | Selection snapshots are authoritative selection context; current listing shown separately | T05 |
| G26 | P0 | Single-selection races leave multiple chosen items | Replace selector contents atomically under Conversation lock; unique item membership | T05 |
| G27 | P0 | Item selected before/after appointment implies inventory reservation | No Item availability, capacity, holds, or reservation in pilot | T05, T07 |
| G28 | P0 | “Conflict prevention” has no defined participant or interval | One optional scheduled Agent per appointment initially; confirmed intervals protected in PostgreSQL | T07 |
| G29 | P0 | Timezones/DST silently shift appointments | UTC instants plus IANA zone; reject nonexistent local times; require offset for ambiguous times | T07 |
| G30 | P0 | Several appointments share a role and predicates pick arbitrarily | Exactly one current record per conversation/role; explicit replacement retains superseded history | T07 |
| G31 | P0 | Stale UI/AI output overwrites a human correction | Expected revisions; stale mutating actions fail and reload; AI rechecks owner/stage/capabilities | T02 onward, T10 |
| G32 | P0 | Configured expressions can exhaust workers or execute code | Whitelist AST/actions and size/depth/evaluation limits; no eval or arbitrary network actions | T04, T06, T09 |
| G33 | P1 | Team assignment contradicts owner eligibility | Team change clears ineligible owner atomically; routing only assigns eligible actors | T06 |
| G34 | P1 | No eligible agent silently loses a request | Visible team/unassigned queue and reason; deterministic fallback | T06 |
| G35 | P1 | Manual handoff is immediately reversed by automation | Fired rules do not reassert ownership; later unfired conflicting rules remain visible policy | T06 |
| G36 | P1 | Conversation progress percentage lies for any/not expressions | Render evaluator explanation tree; counts only for plain all-of requirements | T04, T09 |
| G37 | P1 | Past-stage fields cannot be corrected or correction rewinds history | Authorized corrections allowed; reevaluate current stage only and retain prior transitions | T03–T07 |
| G38 | P1 | No configuration can complete without an item or appointment | Explicit constant completion predicate and single-stage fixtures | T04, T09 |
| G39 | P1 | Unsafe templates interpolate data as HTML/code | Allowlisted substitutions, escaped output, publication validation | T08–T09 |
| G40 | P1 | Private notes/media leak via messages or broadcasts | Distinct notes; access-checked attachments and realtime subscriptions; permitted projections only | T02, T08, T11 |
| G41 | P1 | AI run continues after reassignment, budget exhaustion, or tool failure | Bounded turns/cost/time; cancel stale output; human handoff and inspectable run record | T10 |
| G42 | P1 | Availability UI promises a slot that is already taken | Offers are advisory; confirmation is authoritative and returns a conflict on races | T07 |
| G43 | P1 | Missing recovery and deployment plan | Worker isolation, recovery sweeps, backup/restore exercise, migration and rollback gates | T11 |
| G44 | P1 | “Worldwide” ignores locale, currency, RTL, and mobile dates | Locale-ready strings, currency-aware decimal prices, IANA zones, phone-sized/RTL checks | T02, T05, T07, T11 |
| G45 | P1 | No defined operating envelope or measurable release gate | Provisional pilot workload and performance targets measured before release | T11 |
| G46 | P1 | No ordered implementation or evidence ledger | Dependency tasks with acceptance gates and explicit TODO/verified status | All |
| G47 | P1 | Appointments cancelled after flow completion leave misleading workflow assumptions | Flow completion records a past outcome; cancellation remains visible, does not silently reopen | T07 |
| G48 | P1 | Required disabled field/catalog/agent makes a flow impossible | Publish linter, runtime blocked reason, administrator remediation without silent skips | T09 |
| G49 | P1 | Completed conversations rerun rules on new messages | New activity raises attention only; explicit new request starts another process | T08 |
| G50 | P1 | Draft preview sends real messages | Pure evaluation preview; synthetic state and proposed actions only | T09 |
| G51 | P2 | Item availability query/manipulation previously discussed as a possibility | Deferred, not a pilot task or hidden property of Items | Deferred |
| G52 | P2 | Multi-participant/group calendars and cross-account conflict detection | Deferred; pilot only promises account-local scheduled Agent exclusivity | Deferred |
| G53 | P2 | Cross-channel customer merging and parallel requests on one provider thread | Manual explicit future design; no guessed identity merges | Deferred |
| G54 | P2 | Automatic migration of active conversations between flow versions | Deferred; pin existing instances and route new instances to newly published version | Deferred |
| G55 | P2 | Graphs, loops, timers, payments, quotes and generic integration actions inflate scope | Extension contract documented; no implementation until requested | Deferred |

## Where the decisions live

- [architecture.md](architecture.md): component boundaries, authority, reliability, deployment.
- [domain-model.md](domain-model.md): persistence and lifecycle contracts.
- [flow-engine.md](flow-engine.md): executable predicate, rule, and progression semantics.
- [testing.md](testing.md): evidence required to prove these decisions.
- [implementation-plan.md](implementation-plan.md): dependencies and acceptance gates.
- [decisions/002-runtime-and-delivery-contracts.md](decisions/002-runtime-and-delivery-contracts.md): rationale and tradeoffs.

## Remaining choices requiring real evidence

These do not block documentation or the initial build: select supported Ruby/Rails versions at bootstrap; choose the first channel/provider with test credentials before its adapter task; measure hosting capacity/cost; establish customer-data retention and recovery objectives with the pilot operator before production. Do not invent provider guarantees or claim legal compliance from an architecture document.


## Subsequent scope: account and AI administration

The 55-entry audit above describes baseline `153315d`. The later user requirement for multi-Account creation, invitations, unified Human/AI assignment and knowledge setup is specified in [Accounts and AI setup](accounts-and-ai-setup.md). Its S1–S6 slices extend T01/T06/T10/T11 and address invitation/last-admin races, AI readiness/pause/capacity, shared/restricted knowledge publication, automatic stage context, and instruction/source revocation. These features remain unimplemented until their acceptance evidence exists.
