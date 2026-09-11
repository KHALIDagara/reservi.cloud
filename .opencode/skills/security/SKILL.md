---
name: security
description: Apply Reservi security rules for multi-tenancy, executable Flow configuration, authorization, webhooks, secrets, attachments, AI Actions, and common Rails risks.
---

# Security for Reservi

Security is domain correctness, especially because Reservi is multi-tenant, has executable business configuration, and may let AI Agents execute Actions.

## Tenant isolation

For every Account-owned query, mutation, or configured reference, ask whether an ID from another Account can succeed.

Prefer scoping from current Account rather than global lookup + later ownership check.

Apply this to:

- Conversations / Customers;
- Agents / Teams;
- Flows / Stages / Rules / Blocks;
- Fields;
- Catalogs / Items / ItemSelections;
- Appointments;
- jobs/search/exports/attachments;
- Turbo/realtime;
- provider callbacks.

A Rule in Account A must never reference an Item, Agent, Team, Field, or other object from Account B.

## Authorization

Authorize server-side. UI hiding is not authorization.

Check:

- Account scope;
- actor capability/role;
- current domain/Stage state when relevant.

Human, AI, and Rule-driven operations must pass the same authoritative domain checks where appropriate.

## Flow configuration is executable configuration

Treat user-configured predicates/actions as code-like input even though arbitrary code is forbidden.

Validate:

- allowed predicate operators;
- allowed reference types;
- reference Account ownership;
- value types;
- allowed Actions;
- Action parameters;
- stable key uniqueness;
- configuration size/depth limits where needed;
- loop/cascade protections at runtime.

Never evaluate user-supplied Ruby, JavaScript, SQL, shell, ERB, or arbitrary expressions.

Do not interpolate configuration into SQL or method names dynamically without strict whitelisting.

## AI tools/actions

Treat model output as untrusted input.

Validate:

- target IDs belong to current Account;
- Action is in Agent capability set;
- structured arguments conform to schema/domain rules;
- current state permits Action;
- approval requirements.

Never let prompt text grant permission or rewrite Flow truth.

## Catalog / Item security

Catalog Item selection must verify:

- Catalog/Item belongs to current Account;
- Item is valid for configured selector/Catalog;
- archived/inactive policy;
- Item attribute input follows configured typed definitions.

Do not let rich descriptions/attributes become unsafe HTML or code execution paths.

## Webhooks

When supported:

- verify signature/authenticity;
- resolve Account from trusted integration identity;
- protect against replay/duplicate delivery;
- rate-limit/guard exposed endpoints appropriately.

## Secrets

Never commit or log API keys, provider tokens, signing secrets, production credentials, or copied `.env` files.

## Attachments and Item images

Validate:

- access authorization;
- content type/size;
- filenames as presentation only;
- externally fetched media against SSRF;
- tenant visibility of uploaded media.

## Rails/web checklist

Consider:

- strong parameters/mass assignment;
- CSRF/session safety;
- XSS from customer/provider/Item content;
- SQL injection;
- open redirects;
- SSRF;
- IDOR;
- credential leakage;
- overly broad CORS/API scopes;
- unsafe deserialization of Flow configuration.

Prefer framework-safe helpers, parameterized queries, and explicit whitelists.

## High-risk review

Changes affecting authentication, authorization, Account scoping, Flow configuration/evaluation, AI tools, integrations, file access, or secrets require negative-path tests and independent review.
