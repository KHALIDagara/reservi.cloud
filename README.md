# Reservi

A mobile-first, conversation-centric operations system. Humans and AI work from the same customer context and configured requirements, with the CRM maintained as a consequence of real work.

**Current status:** architecture and implementation specifications. This repository does not yet contain a bootable Rails application, database schema, or executable test suite. Runtime setup instructions will be added with the foundation task.

## Core model

- Conversation is the customer request and running process.
- Flow is an ordered set of Stages; each Stage contains controls, Rules, and a completion predicate.
- Fields hold facts. Catalogs contain universal selectable Items.
- Appointments are independent time-bound commitments and never require an Item.
- Human Agents, AI Agents and Rules use the same authorized domain operations.

Target stack: Rails, PostgreSQL, Hotwire, Active Job and Active Storage. Keep one monolith and one authoritative state model.

## Start here

1. [Agent operating manual](AGENTS.md)
2. [Product requirements](docs/product-requirements.md)
3. [Gap audit](docs/gap-audit.md)
4. [Architecture](docs/architecture.md), [domain model](docs/domain-model.md), and [flow runtime](docs/flow-engine.md)
5. [Implementation plan](docs/implementation-plan.md)
6. [Invariants](docs/invariants.md) and [testing strategy](docs/testing.md)

For the administration experience, read [Accounts and AI setup](docs/accounts-and-ai-setup.md): multiple Accounts, invitations, AI teammates and shared business knowledge.

The plan contains dependency-ordered tasks and acceptance evidence. No implementation task is currently verified. [Documentation index](docs/README.md) explains the complete reference set.
