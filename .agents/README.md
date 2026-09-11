# Antigravity configuration

Google Antigravity 2.0 discovers this project configuration from `.agents/`:

- `agents/*.md` defines the Reservi lead and specialist agents.
- `skills/*/SKILL.md` exposes the same reusable guidance used by OpenCode.
- `skills/reservi/SKILL.md` provides the `/reservi` end-to-end command.

The skill files in this directory are small adapters. The corresponding `.opencode/skills/<name>/SKILL.md` file is canonical, so product and engineering instructions do not diverge between tools.

OpenCode permission rules in `opencode.jsonc` and `.opencode/agents/*.md` do not configure Antigravity. Antigravity agent frontmatter restricts each agent's tools and command policy, while workspace-level safety settings are inherited by subagents.
