---
name: integration-safety
description: Build safe Reservi integrations for messaging providers, AI providers, webhooks, external calendars, email/SMS, and APIs with adapter boundaries, idempotency, retries, and observability.
---

# Integration Safety

Reservi interacts with messaging channels, AI models, calendars, email/SMS providers, and other APIs. Treat every external system as unreliable and eventually inconsistent.

## Boundary rule

Keep provider-specific payloads, status codes, identifiers, and transport logic in adapters/integration modules. Core domain code speaks Reservi language.

Examples:

- provider message -> normalized inbound Message command/data;
- provider delivery status -> normalized Message delivery state;
- AI output -> proposed Action/Message/Field/ItemSelection/Appointment mutation validated by domain permissions;
- external calendar event -> explicit synchronization behavior, not silent ownership of Appointment truth.

An external provider must not define Flow/Stage truth directly. Normalize durable provider results into the relevant Reservi state, then let normal Flow evaluation operate.

## Webhooks

For every webhook:

- verify authenticity/signature when supported;
- record/derive stable provider event/message identity;
- make processing idempotent;
- acknowledge quickly and push slow work to jobs;
- tolerate out-of-order delivery where possible;
- retain enough metadata to debug without making raw payloads the domain model;
- never trust remote tenant/account identifiers without resolving them through configured integration identity.

## Outbound actions

For Messages/remote mutations:

- define local intent/state before and after remote call;
- decide what retries may repeat safely;
- use provider idempotency keys where available;
- avoid holding DB transactions across slow network calls;
- make customer-visible duplicate sends extremely difficult;
- capture remote IDs needed for reconciliation.

Rule-triggered external Actions require stable logical execution identity so Flow reevaluation cannot duplicate them.

## AI actions

AI is an Agent, but model output is untrusted input.

Enforce:

- explicit capabilities;
- structured Action validation;
- Account scope;
- deterministic domain validation after generation;
- approval where policy requires it;
- auditability when operationally important.

Never let a prompt override server-side authorization, Flow configuration, or invariants.

## External calendar semantics

Reservi Appointment remains local authoritative scheduling truth unless an explicit integration design says otherwise.

Calendar sync must not:

- make selected Catalog Items implicitly `bookable`;
- create a hidden Item -> Appointment requirement;
- bypass Stage/Appointment authorization;
- silently turn remote event state into current Stage truth without reconciliation.

## Failure modes

Design for:

- timeouts;
- 429/rate limits;
- 5xx outages;
- malformed payloads;
- duplicated/delayed events;
- revoked credentials;
- partial success;
- remote success with lost/delayed acknowledgement.

Retries need bounded backoff and observability. Manual reconciliation/dead-letter paths should exist where silent loss would harm customers.

## Observability

Log correlation IDs, Account/channel identity, provider event/request IDs, job IDs, relevant Conversation/Appointment/Rule execution IDs, and normalized outcome.

Avoid secrets or unnecessary sensitive customer content in logs.
