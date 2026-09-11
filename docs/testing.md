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

Because configuration affects in-flight Conversations, test whichever strategy the implementation chooses.

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
