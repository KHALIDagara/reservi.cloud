---
name: rails-engineering
description: Implement Reservi with idiomatic Rails, PostgreSQL, Turbo, Stimulus, jobs, and explicit domain boundaries while avoiding unnecessary framework layers.
---

# Rails Engineering for Reservi

Reservi is a Rails monolith first. Use the framework fully before inventing replacements for it.

## Defaults

Prefer:
- resourceful routes;
- thin HTTP controllers that coordinate domain behavior;
- Active Record models/scopes for data-backed domain behavior;
- plain Ruby objects only when behavior genuinely does not belong to an Active Record model/controller/job;
- Turbo Drive/Frames/Streams for navigation and server-driven updates;
- small Stimulus controllers for browser-only behavior;
- Active Job for asynchronous work;
- Active Storage for attachments;
- standard Rails authentication/authorization primitives and explicit policies where needed;
- PostgreSQL features when they simplify correctness.

## Avoid by default

Do not create architectural layers merely because they are common in other ecosystems:
- repositories;
- DTOs for internal Rails calls;
- command buses;
- interactors for every use case;
- one service object per controller action;
- GraphQL between our own frontend and backend;
- React/Vue state duplicating server state;
- microservices split by model;
- event sourcing/CQRS without a real requirement.

A plain method with a clear name is often better than a framework.

## Domain behavior placement

Put behavior where its truth lives.

Examples:
- assignment transition logic near Conversation/Assignment domain behavior;
- booking conflict rules near Booking/calendar domain behavior;
- provider payload parsing in adapters/integration modules;
- retries/delayed external work in jobs;
- orchestration spanning several records in an explicit domain operation only when a model method would become misleading.

Avoid callbacks for multi-record workflows or external side effects. Callbacks are acceptable for local record normalization/housekeeping when their effects are unsurprising.

## Hotwire rules

Before adding custom JavaScript state, ask whether the server can render the truth.

Use:
- Turbo Frames for independently replaceable UI regions;
- Turbo Streams for server-triggered mutations/real-time updates;
- Stimulus for local interaction such as toggles, focus, keyboard behavior, optimistic affordances, and browser APIs.

Keep Stimulus controllers small and DOM-oriented. Do not turn them into a second domain layer.

## Performance

Optimize observed access paths, not imagined scale.

Watch for:
- N+1 queries;
- repeated counts/aggregations in inbox/calendar screens;
- unbounded message/history loads;
- missing indexes on tenant + foreign key/state/time queries;
- broadcast storms;
- synchronous provider calls on latency-sensitive paths.

Prefer pagination/cursors and targeted eager loading over global caching first.

## Time and identifiers

Store timestamps consistently in UTC and render in account/user timezone.
Use application-generated opaque public identifiers only where they improve safety/API ergonomics; database primary keys can remain implementation details.

## Completion

A Rails change is complete only when tests and the real user flow prove it. A green parser/compiler is not enough.
