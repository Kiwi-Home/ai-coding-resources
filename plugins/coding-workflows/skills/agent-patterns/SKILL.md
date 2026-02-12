---
name: agent-patterns
description: |
  Documents agent frontmatter metadata spec and patterns for creating effective
  project-specific agents. Use when: creating agents, understanding agent
  discovery, or configuring agent metadata.
triggers:
  - creating agents
  - agent frontmatter
  - agent discovery
domains: [agents, discovery, frontmatter]
---

# Agent Patterns

## Agent Discovery

Workflow commands discover agents by scanning `.claude/agents/*.md` files and reading their YAML frontmatter. This enables dynamic specialist dispatch without hardcoded agent names.

### Discovery Algorithm

1. Scan `.claude/agents/*.md` for agent definition files
2. Read frontmatter from each file: extract `name`, `description`, `domains`, `role`
3. Match agents to the current task:
   - Compare issue keywords, labels, and file paths against each agent's `domains` array
   - Domain matching is fuzzy: substring matching and semantic similarity (e.g., "database" matches agent with domain "storage")
4. If no `domains` metadata exists: fall back to matching `description` text against issue content
5. If no agents are found: the command operates without specialist dispatch (solo mode)

### When No Agents Exist

All workflow commands work without agents. When no `.claude/agents/` directory exists:
- `/coding-workflows:design-session` operates as sole reviewer
- `/coding-workflows:plan-issue` plans without specialist input
- `/coding-workflows:review-plan` reviews without adversarial dispatch
- `/coding-workflows:execute-issue` executes without parallel teams

Run `/coding-workflows:setup` for full project initialization, or `/coding-workflows:generate-assets agents` to generate agents only.

---

## Frontmatter Metadata Spec (v1)

Agent files use YAML frontmatter with these fields:

```yaml
---
name: my-reviewer
description: "Reviews database patterns and schema design..."
tools: Read, Grep, Glob, Bash, SendMessage, TaskUpdate, TaskList
domains: [storage, database, schema, vectors, sqlite]
role: reviewer
---
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Agent identifier (used in dispatch and messaging). Naming constraints are documented in project-level validation skills when available. |
| `description` | string | What this agent does (used as fallback for matching) |

### Discovery Fields (v1)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `domains` | list[string] | `[]` | Keywords this agent covers. Used for matching against issue content. |
| `role` | string | `specialist` | One of: `specialist`, `reviewer`, `architect`. Affects dispatch priority. |

### Configuration Fields (v1)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `tools` | string (comma-separated) or array | *(inherits all)* | Tools available to this agent when dispatched. When present, restricts the agent to the listed tools. Omitting the field inherits all tools. Generated agents use the comma-separated string form. Users may add or remove tools freely. For platform-level validation rules, see the `plugin-validation` skill. |
| `skills` | list[string] | `[]` | Skills this agent should preload when dispatched. Informational metadata for tooling and documentation. |

**`tools` parsing:** Tool names are split on commas. Leading and trailing whitespace around each name is trimmed. Trailing commas are ignored. Tool names are case-sensitive (e.g., `Read` not `read`). YAML array syntax (`tools: [Read, Grep]`) is also accepted.

**Naming convention**:
- Project skills: bare name (`billing-patterns`)
- Plugin skills: `plugin:namespace:name` (`plugin:coding-workflows:issue-workflow`)
- User-layer skills: bare name with `@user` suffix (`my-skill@user`) -- only needed to disambiguate when a project skill exists with the same name

**NOT a source of truth**: `skills` is informational, like `generated_at`. Both the `skills` frontmatter list and the "Skills You Should Reference" markdown section are written at generation time as parallel representations. Neither is "derived" from the other. Users may edit either independently. Staleness detection does not compare them.

**Reference integrity at generation time**: When populating `skills`, only include skills that actually exist. In `agents`-only mode, only reference project/plugin skills that are already present. Absent skills are omitted (not speculatively populated). A warning is logged: "Skill `X` would be relevant for agent `Y` but does not exist. Run `/coding-workflows:generate-assets skills` first."

**Runtime tolerance**: If a skill in `skills` cannot be found at dispatch time, the agent operates without it. No error is raised. This is consistent with how `domains` matching works -- advisory, not contractual.

**Example:**

```yaml
---
name: billing-reviewer
domains: [billing, payments, subscriptions]
skills:
  - billing-patterns          # project-level skill
  - payment-validation        # project-level skill
  - plugin:coding-workflows:issue-workflow  # plugin skill (namespaced)
---
```

### Tool Configuration Patterns

The `tools` field distinguishes agent capabilities:

| Pattern | Tools | Use Case |
|---------|-------|----------|
| Review-only | `Read, Grep, Glob, SendMessage, TaskUpdate, TaskList` | Agents that inspect code but never modify it. Safer for adversarial review dispatch. |
| Execution-capable | `Read, Grep, Glob, Bash, Write, Edit, SendMessage, TaskUpdate, TaskList` | Agents that implement changes. Used by `/coding-workflows:execute-issue` for TDD loops. |
| Full access | *(omit field)* | Inherits all available tools. Suitable for general-purpose agents. |

**Why Bash matters:** Including `Bash` grants shell execution capability (running tests, linters, build commands). Review-only agents intentionally omit `Bash` (and `Write`/`Edit`) to ensure they can only observe, not modify. This is a trust boundary, not just a convenience.

**Anti-pattern:** Do not include `Bash` on review-only agents "just in case." If an agent's role is `reviewer`, its tool set should reflect read-only access unless the review workflow requires running tests or linters.

### Role Semantics

| Role | Dispatch Behavior |
|------|-------------------|
| `specialist` | Invoked when issue keywords match domains. Standard input weight. |
| `reviewer` | Invoked for code review and plan critique. May be dispatched adversarially. |
| `architect` | Invoked for cross-cutting concerns. Higher authority in conflict resolution. |

### Provenance Fields (v1) -- Agents and Skills

> **Authoritative definition.** This is the canonical reference for provenance fields. Other skills (`asset-discovery`, `codebase-analysis`) reference these definitions for classification and staleness detection.

These fields apply to both agent files (`.claude/agents/*.md`) and skill files (`.claude/skills/*/SKILL.md`). The fields are identical across both asset types.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `generated_by` | string | *(absent)* | Generator command that created this asset. Presence = generated. Absence = manual. Current value: `generate-assets`. Legacy values: `generate-agents`, `generate-skills` (v3), `workflow-generate-agents`, `workflow-generate-skills`, `workflow-setup` (pre-v3). All values classify as "generated". |
| `generated_at` | string | *(absent)* | ISO date (`YYYY-MM-DD`) of generation. For UX display ("generated 6 months ago"). |

**Examples:**

```yaml
# GOOD: Generated agent with provenance
---
name: billing-reviewer
description: "Reviews billing domain patterns..."
domains: [billing, payments, subscriptions]
skills: [billing-patterns, plugin:coding-workflows:issue-workflow]
role: reviewer
generated_by: generate-assets
generated_at: "2026-02-08"
---

# GOOD: Hand-crafted agent (no provenance fields)
---
name: api-reviewer
description: "Reviews API patterns..."
domains: [api, routes]
role: reviewer
---

# BAD: Adding provenance to a manually created agent
---
name: api-reviewer
generated_by: generate-assets  # misleading
---

# BAD: Removing provenance after edits
---
name: billing-reviewer
# provenance removed -- now staleness detection can't identify this as generated
---
```

**Conceptual note:** Provenance records origin, not current state. A generated agent that has been hand-edited retains its `generated_by` field -- this is intentional. Provenance does not imply expendability; generated assets may contain valuable hand-tuned knowledge.

### Reserved Fields (v2)

These fields are planned but not yet used by workflow commands:

| Field | Purpose |
|-------|---------|
| `authority` | Veto power on specific scope (e.g., `authority: veto`) |
| `authority_scope` | What the agent has authority over (e.g., `vision-alignment`) |
| `cross_cutting` | Whether agent concerns span all domains (triggers multi-round deliberation) |

---

## Agent File Structure

A well-defined agent file has these sections:

```markdown
---
name: api-reviewer
description: "Reviews API patterns, async code, and request handling"
tools: Read, Grep, Glob, Bash, SendMessage, TaskUpdate, TaskList
domains: [api, routes, async, http, endpoints, middleware]
role: reviewer
---

# API Reviewer

## Your Role
Review API code for correctness, performance, and consistency with project patterns.

## Project Conventions
- [Framework]-specific patterns to enforce
- Error handling conventions
- Authentication/authorization patterns

## Settled Decisions
Decisions that are NOT up for debate:
- [Decision 1]: [rationale]
- [Decision 2]: [rationale]

## Review Checklist
- [ ] Endpoints follow naming convention
- [ ] Error responses use standard format
- [ ] Input validation on all external inputs
- [ ] Tests cover happy path and error cases

## Skills You Should Reference
- [Relevant skill names from project]
```

---

## Examples by Tech Stack

### Python / FastAPI

```yaml
domains: [api, fastapi, routes, pydantic, async, middleware]
role: reviewer
```

Key review areas: async patterns, Pydantic model design, dependency injection, error handling, type hints.

### TypeScript / Next.js

```yaml
domains: [pages, components, api-routes, server-actions, middleware]
role: reviewer
```

Key review areas: server vs client components, data fetching patterns, type safety, bundle size.

### Ruby / Rails

```yaml
domains: [models, controllers, services, jobs, migrations]
role: reviewer
```

Key review areas: ActiveRecord patterns, N+1 queries, service objects, background jobs.

### Rust / Actix

```yaml
domains: [handlers, middleware, state, extractors, database]
role: reviewer
```

Key review areas: ownership patterns, error handling with `thiserror`, async runtime, type safety.

### Go / Standard Library

```yaml
domains: [handlers, middleware, repository, service, grpc]
role: reviewer
```

Key review areas: error wrapping, context propagation, interface design, goroutine safety.

---

## What Makes Agents Effective

### High-Value Agent Content

1. **Project-specific conventions** that aren't in CLAUDE.md
2. **Settled decisions** that should never be re-debated
3. **Common gotchas** specific to the codebase
4. **Review checklists** tuned to actual past issues

### Low-Value Agent Content

1. Generic language/framework advice (Claude already knows this)
2. Copy-pasted documentation from libraries
3. Overly broad domain coverage (better to have focused agents)
4. Implementation instructions (agents review, they don't implement)

### Scaffolding vs Hand-Tuned

Generated agents (from `/coding-workflows:generate-assets`) provide scaffolding with TODO placeholders. **Hand-edited agents with project-specific knowledge are significantly more effective.**

The progression:
1. Generate scaffolding with `/coding-workflows:generate-assets`
2. Fill in project conventions and settled decisions
3. Add review checklists based on past code review feedback
4. Iterate as the project evolves

---

## Conflict Resolution

When multiple agents are dispatched and disagree:

| Scenario | Resolution |
|----------|------------|
| `architect` vs `specialist` | Architect has higher authority on cross-cutting concerns |
| `reviewer` vs `reviewer` | Confidence-weighted: higher confidence wins |
| Security concern vs any | Security concerns take priority |
| All low confidence | Escalate to human |

Explicit conflict overrides can be configured in `.claude/workflow.yaml` under `deliberation.conflict_overrides`.

---

## Related Skills

- `coding-workflows:asset-discovery` -- Provides discovery location tables and similarity heuristics used by generator commands to detect duplicate assets before scaffolding. The heuristics are complementary to this skill's runtime dispatch matching.
- `coding-workflows:codebase-analysis` -- Criteria for analyzing codebases to inform asset generation. Used by `generate-assets` to detect domains, conventions, and coverage gaps before proposing agents and skills. Also defines staleness evaluation criteria for provenance-aware re-generation.
