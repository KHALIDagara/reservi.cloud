---
name: security
description: Apply Reservi security rules for multi-tenancy, authorization, webhook authenticity, secrets, attachments, AI tool actions, and common Rails web risks.
---

# Security for Reservi

Security is part of domain correctness, especially because Reservi is multi-tenant and may let AI agents execute actions.

## Tenant isolation

For every account-owned query or mutation, ask whether a guessed ID from another account can succeed.

Prefer:

```ruby
current_account.conversations.find(params[:id])
```

over globally finding the record and checking ownership later.

Apply the same thinking to jobs, search, exports, attachments, Turbo streams, and provider callbacks.

## Authorization

Authorize server-side. UI hiding is not authorization.

Check both:
- account scope;
- actor capability/role for the requested action.

AI and human agents must go through the same authoritative checks where appropriate.

## AI tools/actions

Treat model output as untrusted input.

Validate:
- target IDs belong to the current account;
- action is in the Agent's capability set;
- structured arguments conform to schema/domain validation;
- current record state permits the action;
- sensitive action approval requirements.

Never let system/user prompt text grant permissions.

## Webhooks

When supported:
- verify signature/authenticity before processing;
- resolve tenant from trusted integration/channel configuration;
- protect against replay/duplicate delivery with event IDs/idempotency;
- rate-limit or otherwise protect exposed endpoints appropriately.

## Secrets

Never commit:
- API keys;
- provider tokens;
- private signing secrets;
- production credentials;
- copied `.env` files.

Never place secrets in normal logs or exception messages.

## Attachments

Validate:
- authorization to access;
- content type/size constraints appropriate to use;
- filenames are presentation only, not trusted paths;
- externally fetched media cannot become an unrestricted SSRF primitive.

## Rails/web checklist

Consider:
- mass-assignment/strong parameter boundaries;
- CSRF/session safety;
- XSS from customer/provider content;
- SQL injection through handcrafted queries;
- open redirects;
- unsafe URL fetching/SSRF;
- insecure direct object references;
- credential leakage in URLs/logs;
- overly broad CORS/API permissions if APIs are introduced.

Prefer framework-safe helpers and parameterized queries over manual string construction.

## Review high-risk changes

Any change affecting authentication, authorization, tenant scoping, AI tools, integrations, file access, or secrets should receive explicit negative-path tests and independent review.
