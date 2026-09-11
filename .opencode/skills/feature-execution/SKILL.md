---
name: feature-execution
description: Execute a Reservi feature or change from requirement through implementation, verification, review, and documentation without losing architectural coherence.
---

# Feature Execution

Use this skill for any feature, behavior change, product-tied refactor, or cross-cutting engineering task.

## Goal

Deliver the smallest complete vertical slice that advances Reservi while preserving its canonical ontology and invariants.

## 1. Understand the requested behavior

Translate the request into observable behavior.

Identify:

- actor;
- trigger;
- current Flow/Stage context if relevant;
- expected result;
- persisted truth;
- predicates / completion requirements;
- Actions / side effects;
- permissions;
- failure behavior;
- configuration semantics;
- acceptance criteria.

Do not invent behavior before inspecting current code/docs.

## 2. Classify the domain need before creating a model

Ask:

```text
Fact about Customer/request?          -> Field
Reusable selectable business thing?  -> Catalog Item
Time-bound commitment?                -> Appointment
```

Examples:

- budget, city, surface -> Field;
- service, car, property, room, treatment -> Catalog Item;
- consultation, pickup, viewing, site visit -> Appointment.

Only add a new first-class concept when it owns a real lifecycle/invariant these cannot express.

Never add a special `Service`/`Resource` workflow model solely because a business calls an Item by that name.

## 3. Inspect before designing

Trace the current path through:

- routes;
- controllers;
- models;
- Flow/Stage evaluation;
- Fields/Catalogs/Items/Appointments as relevant;
- queries/scopes;
- jobs;
- views/Turbo/Stimulus;
- integrations;
- schema/indexes/constraints;
- tests.

Reuse sound existing patterns.

## 4. Identify invariants and risks

Read `docs/invariants.md`.

Always consider:

- Account isolation;
- authorization;
- stable configured references;
- duplicate external events;
- repeated Rule evaluation;
- Action idempotency;
- concurrent Stage completion;
- concurrent assignment;
- defined Appointment conflicts;
- stale browser state;
- configuration changes while Conversations are in-flight;
- retries / partial external failure.

For Flow work also explicitly ask:

- Did we make Service special?
- Did Item selection accidentally imply reservation?
- Did Appointment become dependent on Item/bookability?
- Did we create another condition language?

## 5. Design the smallest coherent change

Prefer a vertical slice through the monolith over a generalized framework.

For persistence define:

- source of truth;
- Account ownership path;
- foreign keys;
- access indexes;
- uniqueness/check/exclusion constraints for actual invariants;
- deletion/archive behavior;
- active configuration compatibility.

For asynchronous work define:

- stable operation identity;
- idempotency;
- retry behavior;
- stale-state handling.

## 6. Define proof before implementation

Map each acceptance criterion to proof:

- predicate/domain test;
- request/integration test;
- job test;
- system/browser test;
- concurrency test;
- manual operational check.

For Flow-related work include architecture regression scenarios where relevant:

- Appointment with no Item;
- Item with no Appointment;
- Appointment before Item;
- Item before Appointment;
- repeated Rule evaluation;
- concurrent Stage completion.

## 7. Implement in small reversible steps

Keep diffs focused.

- no unrelated refactors;
- no casual dependencies;
- provider logic stays at boundaries;
- prefer Turbo/Stimulus to a client framework;
- no arbitrary code execution in user Rules;
- no broad callback webs for Flow progression;
- use stable keys/IDs rather than labels for configured references.

## 8. Verify

Run focused tests, then surrounding tests.

For user-visible Flow changes exercise the real browser path including mobile viewport when appropriate.

Check:

- happy path;
- blocking/incomplete path;
- authorization/tenant boundary;
- duplicate/retry behavior;
- concurrency where truth can race;
- explainability of automated Actions;
- refresh restores the same truth.

## 9. Review independently

Inspect complete `git diff`.

For meaningful changes ask `reviewer` to review the actual diff. Fix high-confidence findings and re-run relevant proof.

## 10. Update durable context only when truth changed

Update product/flow/domain/architecture/invariant/testing docs when the durable model changes.

Do not use docs as a changelog.

## 11. Report precisely

State:

- behavior delivered;
- areas/files changed;
- tests/checks actually run;
- unresolved risks/assumptions;
- configuration/migration behavior if relevant.

## Definition of done

A change is done when:

- requested behavior exists;
- design fits Reservi's Field / Catalog Item / Appointment classification;
- relevant invariants remain true;
- Flow semantics remain deterministic where applicable;
- tests prove meaningful behavior;
- UI behavior is exercised where appropriate;
- diff is reviewed;
- durable docs match reality;
- no verification claim is fabricated.
