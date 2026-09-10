---
name: integration-safety
description: Build safe Reservi integrations for messaging providers, AI providers, webhooks, email/SMS, and external APIs with adapter boundaries, idempotency, retries, and observability.
---

# Integration Safety

Reservi will interact with messaging channels, AI models, calendars, email/SMS providers, and other APIs. Treat every external system as unreliable and eventually inconsistent.

## Boundary rule

Keep provider-specific payloads, status codes, identifiers, and transport logic in adapters/integration modules. The core domain should speak Reservi language.

Examples:
- provider message -> normalized inbound message command/data;
- provider delivery status -> normalized message delivery state;
- AI output -> proposed action/message/structured fields validated by domain permissions;
- external calendar event -> explicit synchronization behavior, not silent ownership of booking truth.

## Webhooks

For every webhook:
- verify authenticity/signature when supported;
- record or derive a stable provider event/message identifier;
- make processing idempotent;
- acknowledge quickly and push slow work to jobs;
- tolerate out-of-order delivery where possible;
- retain enough metadata to debug without making raw payloads the domain model;
- never trust tenant/account identifiers supplied by the remote caller without resolving them through configured credentials/channel identity.

## Outbound actions

For messages/remote mutations:
- define local state before and after the remote call;
- decide what retries may repeat safely;
- use idempotency keys where the provider supports them;
- avoid holding database transactions open across slow network calls;
- make customer-visible duplicate sends extremely difficult;
- capture remote identifiers needed for reconciliation.

## AI actions

AI is an Agent, but model output is untrusted input.

Enforce:
- explicit capabilities/permissions;
- structured validation for actions;
- tenant scope;
- deterministic domain validation after generation;
- human approval for actions designated sensitive by product policy;
- auditability of the instruction/context/action when operationally important.

Never let a prompt override server-side authorization or invariants.

## Failure modes

Design for:
- timeouts;
- 429/rate limits;
- 5xx/provider outage;
- malformed payloads;
- duplicated events;
- delayed events;
- credentials revoked;
- partial success;
- provider says success but callback is delayed/missing.

Retries need bounded backoff and observability. Dead-letter/manual reconciliation paths should exist when silent loss would harm customers.

## Observability

Log correlation identifiers, tenant/channel identity, provider request/event IDs, job IDs, and normalized outcome. Avoid logging secrets or unnecessary sensitive message/customer data.
