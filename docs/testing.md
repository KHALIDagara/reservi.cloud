# Reservi Testing Strategy

## 1. Purpose

Testing in Reservi exists to prove product truth, protect invariants, and let humans and AI agents change a configurable operational system safely.

The goal is not maximum test count. The goal is confidence that:

- configured Stages progress correctly;
- Rules execute exactly when intended;
- Actions preserve domain invariants;
- Catalog/Item works across business verticals without special-case architecture;
- Appointment is independent from Item selection;
- tenant boundaries hold;
- retries/concurrency do not duplicate Actions or Stage transitions;
- humans and AI operate on the same authoritative state;
- critical flows work through the real UI.

Read `docs/flow-engine.md` and `docs/invariants.md` before testing Flow/Stage/Rule/Catalog/Appointment behavior.

---

## 2. Principles

### Test behavior, not implementation trivia

Prefer assertions about authoritative state, progression, assignments, selected Items, Appointments, Messages, authorization, and side effects.

### Use the lowest useful layer

Prove deterministic predicate/domain logic cheaply, then add request/job/system/concurrency proof where boundaries create risk.

### Configurability requires scenario testing

Do not test only one default Flow such as qualification -> service -> appointment.

The suite must prove different valid account configurations without hard-coded ordering assumptions.

### Bugs normally gain regression tests

Reproduce the defect, then protect the corrected product truth.

### Tests do not replace DB integrity

Use database constraints/locking/exclusion semantics where durable truth requires concurrency protection.

---

## 3. Predicate / expression tests

The shared predicate engine needs fast tests for:

- equality/inequality;
- exists/missing;
- numeric/date comparison where supported;
- all/any/not composition where supported;
- Customer/Conversation Field references;
- owner/team references;
- ItemSelection references;
- Item price/attribute references;
- Appointment role/status references;
- invalid/stale references;
- cross-account references rejected;
- deterministic result for identical state/configuration.

No arbitrary-code tests are needed because arbitrary user code must not be supported.

---

## 4. Domain/model tests

Use for:

- Field definition/value validation;
- Catalog/Item lifecycle and attribute validation;
- ItemSelection single/multiple semantics;
- stable selector keys across label changes;
- Stage completion;
- Flow ordering/current Stage;
- assignment/history;
- Appointment state/time/conflict semantics actually defined by product;
- Agent capability rules;
- Action domain operations.

Examples:

```text
Catalog Item
- Cars and Services use the same Item model semantics
- Item from another Account cannot be selected
- archived Item cannot be newly selected when policy forbids it
```

```text
Appointment
- can be created with no Item selection
- remains valid when no Catalog exists
- does not require service_id/item_id/bookable flag
```

---

## 5. Flow runtime tests

The Flow runtime is a critical subsystem.

Prove:

```text
state mutation
-> applicable Rules evaluate
-> matching Actions execute
-> resulting authoritative state is re-read
-> completion predicate evaluates
-> Stage remains or advances exactly once
```

At minimum:

- no matching Rule -> no side effect;
- matching Rule -> intended Action;
- repeated evaluation with unchanged true predicate -> no duplicate irreversible Action;
- Action changes state -> completion sees resulting state;
- completion false -> Stage remains;
- completion true -> advances once;
- newly entered Stage follows defined evaluation semantics;
- bounded cascade prevents infinite Rule loop;
- stale/invalid configuration fails safely and observably.

---

## 6. Configuration-composition tests

Protect the product's architectural flexibility with explicit scenarios.

### Appointment first, no Catalog

```text
Stage 1: Appointment
complete when Appointment confirmed
```

Expected: works with no Catalog, Item, or Service concept configured.

### Catalog selection only

```text
Stage 1: Vehicle selector -> Cars
complete when vehicle selected
```

Expected: Flow completes without Appointment.

### Item then Appointment

```text
Stage 1: Vehicle selector -> Cars
Stage 2: Pickup Appointment
```

Expected: selected vehicle remains visible in Conversation context; Appointment does not require Item linkage/bookable flag.

### Appointment then Item

```text
Stage 1: Consultation Appointment
Stage 2: Package selector
```

Expected: valid progression; no hidden ordering assumption.

### Same Item abstraction across verticals

Create Catalogs `Services`, `Cars`, `Properties` with Items and prove selectors/predicates use the same domain path.

These scenarios are architecture regression tests, not merely examples.

---

## 7. Request/integration tests

Use for:

- authentication/authorization;
- tenant scoping;
- Stage builder/configuration endpoints;
- invalid cross-account Rule references;
- Field updates;
- Catalog/Item CRUD and selection;
- Appointment mutations;
- manual assignment;
- webhook endpoints;
- Turbo/HTML contracts where important.

Every important account-owned mutation needs tenant/authorization proof somewhere in the suite.

---

## 8. Job tests

Use for:

- retryable Rule Actions;
- outbound Messages;
- AI processing;
- provider reconciliation;
- delayed external effects.

Always test second execution and partial failure.

Questions:

- Does retry duplicate a Message?
- Does retry recreate an Appointment?
- Does retry repeat the same logical assignment?
- Does the job re-scope through Account?
- Does it use stable Rule/Action execution identity?

---

## 9. System/browser tests

Keep a small number of high-value end-to-end flows.

### Stage completion

```text
admin configures Stage requirements
-> operator opens Conversation
-> completes required state
-> progress indicator updates
-> Stage advances
```

### Assignment Rule

```text
City=Marrakech
-> Rule assigns Ahmed
-> owner updates visibly
-> explanation/history identifies Rule
-> repeated evaluation does not duplicate logical action
```

### Catalog selector

```text
admin creates Cars Catalog + Items
-> adds Vehicle selector to Stage
-> operator selects Range Rover Evoque
-> refresh
-> selection remains
-> Stage completion sees it
```

### Appointment without Item

```text
Stage contains Appointment block
-> no Catalog configured
-> create/confirm Appointment
-> Stage completes
```

### Item + later Appointment

```text
select Villa Agdal in Property Stage
-> advance
-> create Viewing Appointment in later Stage
-> Appointment view displays relevant Conversation selection
-> no bookable/resource/service field is required
```

### Human/AI handoff

Where deterministic doubles are appropriate:

```text
AI reads missing Stage requirement
-> performs allowed action
-> hands off
-> human sees same Conversation state
```

System tests must also cover phone-sized viewport for core workflows.

---

## 10. Concurrency tests

Add targeted concurrency tests where simultaneous operations can break truth.

High-risk examples:

- two evaluators complete/advance the same Stage;
- two Rules/users assign the same Conversation;
- duplicate webhooks process simultaneously;
- two jobs execute the same irreversible Rule Action;
- two users modify the same selection/state;
- two users create conflicting Appointments for an explicitly constrained Agent.

Do not invent Item-level scheduling conflict tests unless the product actually introduces item-level reservation semantics.

Use barriers/transactions/database assertions rather than arbitrary sleep timing.

---

## 11. Messaging and integration idempotency

Prove:

- duplicate inbound provider ID -> one Message;
- repeated delivery callback safe;
- outbound retry does not casually double-send;
- Rule-triggered send executes once per logical trigger;
- provider payload is normalized before Flow predicates consume relevant state.

Normal suite should not depend on live external APIs.

---

## 12. AI-specific testing

Separate deterministic product correctness from probabilistic model quality.

Deterministic tests cover:

- current Stage/missing-requirement representation;
- tool/capability list;
- structured action validation;
- authorization after model output;
- allowed Field/ItemSelection/Appointment actions;
- cross-account target rejection;
- Rule/domain invariant preservation;
- idempotent action execution;
- escalation/handoff behavior.

Model-quality evaluations may later cover intent/extraction/tone, but exact LLM strings do not belong in the normal unit suite.

---

## 13. Configuration evolution tests

Because configuration affects in-flight Conversations, test immutable published FlowVersions, pinned Conversations, stable referenced field types, and explicit selection snapshots as defined in the architecture.

Cases include:

- Stage rename;
- Stage reorder/archive;
- required Block removed;
- completion expression changed;
- Rule changed;
- Field definition changed;
- Catalog archived;
- Item archived/changed while selected;
- Agent removed.

The expected behavior must be explicit rather than accidental.

---

## 14. Security verification

Test relevant boundaries:

- authentication required;
- server-side authorization;
- strict Account scope;
- cross-account Catalog Item selection rejected;
- cross-account Rule references rejected;
- unsafe configuration operators rejected;
- arbitrary code not accepted in predicates/actions;
- webhook authenticity;
- attachment access;
- AI actions cannot bypass capabilities.

---

## 15. Performance verification

For hot paths inspect:

- N+1 queries while rendering/evaluating Stage state;
- unbounded Message/Item loads;
- repeated predicate queries;
- missing indexes for stable keys/current Stage/selection lookups;
- excessive broadcasts;
- synchronous external calls;
- repeated no-op Flow evaluation.

Optimize measured bottlenecks only.

---

## 16. Test execution workflow

During implementation:

1. run focused test/example;
2. run containing file;
3. run related subsystem tests;
4. run relevant system/browser flow;
5. run concurrency proof when required;
6. run broader/full suite for meaningful integration/high-risk change;
7. run configured lint/security/static checks.

Report exactly what was executed. Never imply a browser flow or full suite ran if it did not.

---

## 17. Definition of verified

A change is verified only when applicable proof exists for:

- requested behavior;
- relevant invariant(s);
- tenant/authorization boundary;
- Flow/Rule semantics;
- retry/duplicate/concurrency behavior;
- critical UI path;
- regression around defects;
- architectural independence where relevant (especially Appointment vs Item selection).

## 18. Required failure and race acceptance matrix

These are implementation acceptance cases, not tests that already exist. Run against PostgreSQL for locking/exclusion behavior. Concurrency tests use independent database connections and barriers, not transactional fixtures that conceal commits or arbitrary sleeps. Inject crashes at the indicated boundary and assert durable outcomes after recovery.

| ID | Scenario / injected failure | Required evidence | Task |
|---|---|---|---|
| AC01 | Direct cross-account nested association | Database rejects relational mismatch; JSON config rejected at publication/execution | T01, T04 |
| AC02 | Same-account operator requests another team's thread, attachment or stream | Denied despite valid Account membership | T02 |
| AC03 | Two simultaneous claims / stale edits | One claim wins; stale write cannot overwrite newer state | T02, T06 |
| AC04 | Built-in name versus custom name; false/zero/null | Single writable source; correct type/presence semantics | T03 |
| AC05 | Customer change commits, fan-out worker crashes mid-batch | All active related requests eventually observe latest revision once resumed; completed state unchanged | T03, T04 |
| AC06 | Publish v2 while v1 has active conversations | v1 instance remains on v1; newly created instance uses v2 | T04 |
| AC07 | Two evaluators see true gate | One unique stage transition and coherent current pointer/history | T04 |
| AC08 | Commit state then crash before job enqueue | Sweeper detects and completes pending evaluation | T04 |
| AC09 | Missing comparison under not; empty any/all/selection | Unknown cannot pass by negation; invalid AST rejected; collection semantics explicit | T04 |
| AC10 | More than ten immediately ready stages | Bounded continuation completes without losing work or marking false failure | T04 |
| AC11 | Catalog edit/archive after selection | Selected snapshot/predicates stable; new selection forbidden if archived | T05 |
| AC12 | Concurrent single/multi selector replacements | Legal cardinality and set membership; stale operation rejected | T05 |
| AC13 | Rule predicate true→false→true; duplicate jobs | Successful logical rule and Message intent occur once | T06, T08 |
| AC14 | Action 1 assigns, Action 2 fails validation | Entire local rule bundle rolled back; blocked reason visible, prior user edit retained | T06 |
| AC15 | Failed rule then predicate becomes false | Error no longer blocks; no invented success/action record | T06 |
| AC16 | Later rule enables earlier unfired rule; two assignments compete | Deterministic ordered passes and explainable final owner | T06 |
| AC17 | Human handoff after routing rule succeeded | Fired rule does not reassign again | T06 |
| AC18 | Account/AI/rule capability revoked after work queued | New operation/send claim denied or cancelled as specified; historical attribution preserved | T06, T08, T10 |
| AC19 | Two confirmed appointments overlap same Agent | Database rejects one; adjacency allowed; no Item scheduling involved | T07 |
| AC20 | Reschedule conflicts; role replaced after cancellation | Old valid interval retained on failure; one current role, old history preserved | T07 |
| AC21 | DST gap/fold and viewer timezone change | Invalid local time rejected, ambiguous offset chosen, same UTC instants displayed | T07 |
| AC22 | Appointment cancelled after terminal Flow completion | Appointment updates and attention show truth; past Flow does not rewind | T07 |
| AC23 | Duplicate first inbound / crash after receipt acknowledgement | One identity/thread/message; durable receipt reprocessed safely | T08 |
| AC24 | Provider accepts send, client times out | Unknown outcome; no blind resend without deduplication/reconciliation contract | T08 |
| AC25 | Worker dies after claiming/before recording provider result | Expired in-flight attempt is reconciled/unknown, not automatically assumed unsent | T08 |
| AC26 | Delivered callback then delayed sent callback | No delivery-state regression; duplicate callback harmless | T08 |
| AC27 | Inbound after completed process | Attention raised, completed rules not rerun; new request requires explicit thread switch | T08 |
| AC28 | Draft preview of assignment/send/appointment rules | No mutation, external call or queued side effect | T09 |
| AC29 | Unsupported/deep AST, foreign target, conflicting role | Publication error identifies location and reason | T09 |
| AC30 | Human takes over while AI is inferring / reply pending | Stale action rejected; pending unclaimed AI send cancelled; in-flight send reconciled honestly | T10 |
| AC31 | Duplicate AI trigger and repeated tool action ID | One active run; idempotent operation, bounded tool budget | T10 |
| AC32 | Provider/model failure or budget exhaustion | Human queue receives actionable context; no silent ownership loss | T10 |
| AC33 | Database/media restore | Clean instance renders known thread, attachment, selection and Appointment | T11 |
| AC34 | All composition fixtures at phone size | Field-only, literal single-stage, catalog-only, appointment-only and both orderings work | T04–T11 |
| AC35 | Cross-customer rules target Agents A/B in reversed order, interleaving Item actions | Complete pre-acquired lock sets prevent inversion; concurrent results remain valid | T09, after T05–T07 |
| AC36 | Create workspace appointment in field-only Flow | Ad hoc role works without Block/Item; configured predicates cannot collide with ad hoc namespace | T07 |
| AC37 | Pinned Rule target permanently deactivated | Explicit cancellation and linked new request on corrected version recover without silently replaying old effects | T09 |
| AC38 | Template requests a private/unknown field or embeds hostile text | Publication/runtime validation denies invalid access, HTML stays escaped, retry body unchanged | T08, T09 |

## 19. Documentation validation versus runtime proof

For changes confined to planning documents, check the complete diff, local relative links, task references, invariant identifiers, status claims and contradictions. Obtain independent review as AGENTS.md requires. Do not bootstrap an application just to pretend documentation has runtime tests.

When code exists, each task in [implementation-plan.md](implementation-plan.md) records its actual command/results and evidence. Existing generic guidance above does not require repeating the full suite for every small edit: broaden testing only for a named residual risk or CI gate. Provider contract and model-quality checks supplement deterministic product tests; they cannot replace them.
