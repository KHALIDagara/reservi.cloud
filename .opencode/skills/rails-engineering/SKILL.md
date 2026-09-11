---
name: rails-engineering
description: Implement Reservi with idiomatic Rails, PostgreSQL, Turbo, Stimulus, jobs, and explicit domain boundaries while avoiding unnecessary framework layers.
---

# Rails Engineering for Reservi

Reservi is a Rails monolith first. Use the framework fully before inventing replacements for it.

Load `flow-engine` for Flow/Stage/Rule/Field/Catalog/Item/Appointment work.

## Defaults

Prefer:
- resourceful routes;
- thin HTTP controllers coordinating domain behavior;
- Active Record models/scopes for data-backed domain behavior;
- focused domain operations only when orchestration genuinely spans records;
- Turbo Drive/Frames/Streams for server-driven UI;
- small Stimulus controllers for browser-only behavior;
- Active Job for asynchronous work;
- Active Storage for Item/message/other attachments where appropriate;
- standard Rails authentication/authorization patterns;
- PostgreSQL features when they simplify correctness.

## Avoid by default

Do not create layers merely because another ecosystem commonly uses them:
- repositories;
- DTOs for internal Rails calls;
- command buses;
- interactors for every use case;
- one service object per controller action;
- GraphQL between our own frontend/backend;
- React/Vue state duplicating server truth;
- microservices split by model;
- event sourcing/CQRS without a real requirement;
- STI/subclass hierarchies for Service/Car/Property/Room Items merely to encode business vocabulary.

A clear Rails model/domain method is often better than a framework.

## Domain behavior placement

Put behavior where its truth lives.

Examples:
- assignment transition logic near Conversation/Assignment behavior;
- Catalog/Item presentation and typed attributes near Catalog/Item domain behavior;
- ItemSelection behavior near Conversation/selection domain behavior;
- Appointment time/status/conflict rules near Appointment/calendar behavior;
- Flow predicate/evaluation logic in a small explicit Flow namespace/domain operation;
- provider payload parsing in adapters/integrations;
- retries/delayed external work in jobs.

Do not make Appointment depend on Service/Item/bookable semantics unless an explicit future requirement changes the model.

Avoid callbacks for multi-record Flow progression or external side effects. Prefer explicit invocation after durable mutations. Callbacks are acceptable for unsurprising local normalization/housekeeping.

## Flow implementation posture

Preserve:

```text
Conversation = State + Current Stage
Stage = Blocks + Rules + Completion Predicate
Rule = Predicate + Actions
```

Use stable keys/IDs for configurable references.

Structured predicate/configuration JSON is acceptable if strongly validated and hidden behind domain APIs/value objects. Do not spread raw JSON/hash inspection throughout controllers/views/models.

Rule Actions must call normal protected domain operations.

Stage advancement and irreversible Rule Actions require idempotency/concurrency design.

## Hotwire rules

Before custom JavaScript state, ask whether the server can render the truth.

Use:
- Turbo Frames for replaceable UI regions;
- Turbo Streams for server-triggered updates;
- Stimulus for local interaction such as toggles, focus, keyboard behavior, drag/reorder affordances, and browser APIs.

Keep Stimulus DOM-oriented. Do not put Flow truth in JavaScript.

## Performance

Optimize observed access paths.

Watch for:
- N+1 queries while rendering/evaluating Stage state;
- repeated Catalog/Item lookups;
- unbounded message/history lists;
- missing indexes on Account/current Stage/stable keys/time;
- repeated predicate queries;
- broadcast storms;
- synchronous provider calls.

Prefer targeted eager loading/pagination/indexes before broad caching.

## Time and identifiers

Store timestamps consistently in UTC and render in relevant timezone.

Use stable opaque/system keys where configuration needs identity across label changes.

## Completion

A Rails change is complete only when tests and the real user flow prove it. A green parser/compiler is not enough.
