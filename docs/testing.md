# Reservi Testing Strategy

## 1. Purpose

Testing in Reservi exists to prove product truth, protect invariants, and let humans and AI agents change the system quickly without fear-driven overengineering.

The goal is not maximum test count or line coverage.

The goal is confidence that:

- the requested behavior works;
- the database remains truthful;
- one tenant cannot affect another;
- retries/duplicate events are safe;
- concurrent operations cannot create impossible states;
- critical user journeys still work through the real interface.

---

## 2. Testing principles

### 2.1 Test behavior, not implementation trivia

Prefer assertions about observable state, authorization, responses, messages, assignments, bookings, and side effects.

Avoid tests that merely pin private method call sequences unless the interaction itself is a contract.

### 2.2 Use the lowest useful layer

Start at the layer where the rule can be proven cheaply and deterministically.

Then add higher-level proof when boundaries/integration create meaningful risk.

### 2.3 Critical workflows deserve system proof

Unit/model/request tests cannot prove that Turbo frames, forms, Stimulus behavior, authorization, and rendered state work together.

Critical operator journeys should have a small number of valuable system/browser tests.

### 2.4 Bugs normally gain regression tests

A bug fix should usually include a test that reproduces the defect before the fix and passes after it.

### 2.5 Tests do not excuse weak database integrity

Do not use tests as a substitute for a unique/check/foreign-key/exclusion constraint when the database can enforce a durable invariant.

### 2.6 Never weaken valid tests to make a change pass

If a test encodes obsolete behavior, update the product requirement/invariant explicitly. Do not silently delete or loosen coverage.

---

## 3. Test layers

## 3.1 Model/domain tests

Use for:

- validation rules;
- state transitions;
- assignment rules;
- qualification validation;
- booking calculations/conflict semantics;
- capability predicates;
- domain methods;
- scope/query semantics;
- history creation rules.

Examples:

```text
Conversation assignment
- assigning an eligible agent changes current owner
- previous assignment is closed/preserved
- assigning an agent from another account is rejected

Qualification
- enum value outside configured options is rejected
- AI and human updates run the same validation
```

Keep these fast and deterministic.

---

## 3.2 Request/integration tests

Use for:

- authentication;
- authorization;
- tenant scoping;
- nested resource lookups;
- controller behavior;
- Turbo/HTML response contracts where important;
- webhook endpoints;
- API/integration boundaries;
- malformed/unauthorized requests.

Every important account-owned mutation should have at least one authorization/tenant-boundary proof somewhere in the suite.

Examples:

```text
- Account A cannot POST an assignment against Account B's conversation ID.
- A valid WhatsApp webhook resolves the configured channel/account.
- A webhook with an invalid signature is rejected.
- Duplicate provider message ID does not create a second Message.
```

---

## 3.3 Job tests

Use for:

- retry behavior;
- idempotency;
- external side-effect orchestration;
- AI processing;
- message sending;
- reconciliation;
- delayed follow-up.

Test the job's durable contract, not every client library call.

Important questions:

- What happens on second execution?
- What happens after a timeout?
- What if the remote side succeeded but the local response was lost?
- Does the job re-scope through the tenant?
- Can retry send a duplicate customer message?

---

## 3.4 System/browser tests

System tests are for workflows where real integration matters.

Priority journeys:

### Inbox and conversation

```text
sign in
→ open assigned/unassigned inbox
→ open conversation
→ read context
→ send reply
→ see reply in timeline
```

### Assignment/handoff

```text
open conversation
→ assign/reassign to eligible agent
→ owner updates visibly
→ history is preserved
```

### Qualification

```text
open conversation
→ fill/update qualification field
→ save
→ refresh
→ value remains correct
```

### Booking

```text
open conversation
→ choose booking action
→ select valid slot
→ confirm
→ booking appears in conversation and calendar
→ reschedule/cancel as relevant
```

### Human/AI handoff

Where deterministic test doubles make it feasible:

```text
AI-assigned conversation
→ AI action reaches allowed domain boundary
→ escalation/handoff to human
→ human sees preserved context
```

System tests should be few, stable, and high-value. Do not use them to test every validation permutation.

---

## 3.5 Concurrency tests

Add targeted concurrency tests where correctness depends on simultaneous operations.

High-risk examples:

- two workers attempt to assign the same conversation;
- two users book the same exclusive slot/resource;
- two duplicate webhooks process simultaneously;
- two jobs attempt the same outbound operation;
- a stale state transition races with a newer one.

A concurrency test should prove the invariant, not rely on arbitrary `sleep` timing.

Use barriers/latches/transactions or direct database-level assertions appropriate to the test framework.

---

## 3.6 Integration contract tests

External provider SDKs should be wrapped behind our adapter boundary.

Test:

- request normalization;
- expected provider payload mapping;
- response/error normalization;
- signature verification;
- idempotency key behavior;
- rate-limit/transient failure classification.

Avoid making the normal test suite dependent on live provider APIs.

Use recorded/sandbox integration checks separately when they provide meaningful confidence.

---

## 4. Mandatory invariant coverage

`docs/invariants.md` is the source of hard truths.

At minimum, the suite should accumulate explicit proof for these classes:

### Tenant isolation

- cross-account reads fail/not found;
- cross-account writes fail;
- search is scoped;
- jobs re-scope;
- broadcasts/subscriptions are scoped.

### Messaging idempotency

- same inbound provider ID twice -> one Message;
- same retryable outbound operation does not casually double-send;
- delivery callback repetition is safe.

### Assignment

- at most one current owner;
- concurrent reassignment resolves consistently;
- history remains truthful;
- ineligible/unauthorized actors are rejected.

### Booking

- invalid time/resource is rejected;
- concurrent exclusive booking cannot double-commit;
- reschedule/cancel state remains consistent;
- conversation and calendar reflect the same record.

### AI actions

- prompt/tool output cannot bypass capability checks;
- invalid structured values are rejected;
- cross-tenant target IDs are rejected;
- disallowed actions require denial/approval according to policy.

---

## 5. Test data strategy

Use factories/fixtures in a way that makes domain intent obvious.

Prefer named setups such as:

```text
account
sales_team
human_agent
ai_agent
customer
whatsapp_channel
conversation
booking
```

over giant generic fixtures with dozens of irrelevant fields.

Keep defaults valid and minimal.

For tenant tests, always create at least two accounts explicitly so cross-account mistakes are visible.

---

## 6. External service strategy

Normal test suite:

- no real LLM/API calls;
- no real WhatsApp/email/SMS sends;
- no dependency on internet availability.

Wrap external clients and inject/stub at the adapter boundary.

Keep provider response examples close to adapter tests when useful.

Secrets must never be required for ordinary tests.

---

## 7. AI-specific testing

Separate deterministic product behavior from probabilistic model quality.

### Deterministic tests

Test:
- prompt/context assembly logic where it is product-critical;
- available tool/capability list;
- structured action schema validation;
- authorization after model output;
- handoff/escalation rules;
- idempotency of executed actions;
- fallback/error behavior.

### Model-quality evaluation

Do not put brittle exact-string LLM expectations into the normal unit suite.

For AI quality, maintain scenario/evaluation fixtures later as product usage matures, e.g.:
- correctly classify service intent;
- ask for missing required qualification;
- do not invent price/availability;
- escalate sensitive/uncertain case;
- produce appropriate language/tone.

These evaluations are distinct from domain correctness tests.

---

## 8. Browser/mobile verification

Reservi is mobile-first.

For UI changes affecting critical workflows, system/manual verification should include a narrow viewport representative of a phone.

Check:

- no critical control is off-screen/inaccessible;
- conversation timeline remains readable;
- composer remains usable;
- assignment/qualification/booking controls remain operable;
- Turbo navigation preserves expected back/forward behavior;
- modals/drawers/forms remain keyboard/focus accessible enough for normal usage.

Do not approve a desktop-only implementation of a core workflow.

---

## 9. Performance verification

Do not add performance tests everywhere.

For hot operational screens/paths, inspect for:

- N+1 queries;
- unbounded message loads;
- repeated counts;
- missing indexes;
- excessive broadcasts;
- synchronous remote calls.

When a performance regression is fixed, add a focused guard when practical (query-count assertion, benchmark outside normal flaky suite, or documented observation).

---

## 10. Security verification

For security-sensitive work, test at least the relevant boundaries:

- authentication required;
- authorization enforced server-side;
- account scope enforced;
- webhook authenticity checked;
- unsafe attachment access denied;
- CSRF/session behavior remains valid;
- mass assignment/parameter handling does not expose privileged fields;
- AI tool actions cannot bypass permissions.

Use static/security tooling appropriate to Rails once the app is bootstrapped, but tools supplement—not replace—behavioral tests.

---

## 11. Test execution workflow

During implementation:

1. run the focused test/example;
2. run the containing test file;
3. run the relevant subsystem tests;
4. run system test for changed critical workflow;
5. run broader/full suite for meaningful integration/high-risk changes;
6. run lint/security/static checks configured by the repository.

Before claiming completion, record exactly what was executed.

If the full suite was not run, say so.

If browser verification was not possible, say so and explain the remaining risk.

---

## 12. Bug-fix workflow

For defects:

```text
reproduce
→ write failing regression test when practical
→ identify root cause
→ make smallest correction
→ regression test passes
→ relevant surrounding tests pass
→ original user/system flow verified
```

Do not start with a broad rewrite.

---

## 13. Test naming

Names should describe behavior and conditions.

Good:

```text
rejects assigning an agent from another account
creates only one message for duplicate provider message id
prevents two confirmed bookings for the same exclusive resource and time
```

Weak:

```text
test assign
test webhook
test booking works
```

A failing test name should make the broken product truth obvious.

---

## 14. Definition of verified

A change is **verified** only when applicable proof exists for:

- requested behavior;
- relevant invariant(s);
- tenant/authorization boundary;
- important retry/duplicate/concurrency behavior;
- critical user interface path;
- regression around the defect/change.

A change can still ship with consciously accepted gaps, but those gaps must be reported rather than hidden behind the word "tested".
