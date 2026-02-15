---
name: agent-patterns
description: |
  Documents agent frontmatter metadata spec and patterns for creating effective
  project-specific agents. Use when: creating agents, understanding agent
  discovery, or configuring agent metadata.
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

## Official Frontmatter Fields

Agent files use YAML frontmatter. Fields are separated into two tiers: required fields that every agent needs, and configuration fields that customize agent behavior.

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Agent identifier (used in dispatch and messaging). Naming constraints are documented in project-level validation skills when available. |
| `description` | string | What this agent does (used as fallback for matching) |

### Configuration Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `tools` | string or array | *(inherits all)* | Tools available to this agent. When present, restricts to the listed tools. Omitting inherits all tools. |
| `disallowedTools` | string or array | *(none)* | Tools to remove from the agent's available set. |
| `model` | string | *(inherit)* | Model override for this agent (`haiku`, `sonnet`, `opus`). |
| `permissionMode` | string | `default` | Controls how the agent handles permission prompts. |
| `maxTurns` | integer | *(unlimited)* | Maximum agentic turns before stopping. |
| `skills` | list[string] | `[]` | Skills injected into agent context at startup. Full content is loaded, not referenced. Affects context budget. |
| `mcpServers` | object | *(none)* | MCP server configurations available to this agent. |
| `hooks` | object | *(none)* | Lifecycle hooks triggered by agent events. |
| `memory` | object | *(none)* | Persistent memory configuration across sessions. |
| `color` | string | *(none)* | Display color in the `/agents` UI. See Claude Code docs for valid values. |

**WARNING -- `skills` injects full content:**
The `skills:` field causes each listed skill's entire SKILL.md content to be loaded into the agent's context window at startup. This is NOT informational metadata. Agents do NOT inherit skills from their parent context. The recommended aggregate budget is ~5,000 tokens per agent across all listed skills. The `/coding-workflows:generate-assets` command includes universal skills (e.g., `plugin:coding-workflows:knowledge-freshness`) that consume a fixed baseline; remaining budget is for domain-specific skills.

**`skills` naming convention:**
- Project skills: bare name (`billing-patterns`)
- Plugin skills: `plugin:namespace:name` (`plugin:coding-workflows:issue-workflow`)
- User-layer skills: bare name with `@user` suffix (`my-skill@user`) -- only needed to disambiguate when a project skill exists with the same name

**Runtime tolerance:** If a skill in `skills` cannot be found at dispatch time, the agent operates without it. No error is raised.

**`tools` parsing:** Tool names are split on commas. Leading and trailing whitespace is trimmed. Trailing commas are ignored. Tool names are case-sensitive (e.g., `Read` not `read`). YAML array syntax (`tools: [Read, Grep]`) is also accepted.

---

## Configuration Guidance

### `model` Selection

| Value | When to Use |
|-------|-------------|
| `haiku` | Simple tasks: linting, formatting checks, boilerplate generation |
| `sonnet` | Standard tasks: code review, implementation, testing |
| `opus` | Complex tasks: architecture review, cross-cutting analysis, nuanced judgment |
| *(omit)* | Inherits from parent context. Recommended default. |

### `permissionMode` Values

| Mode | Behavior | Security Note |
|------|----------|---------------|
| `default` | Prompts for permission | Safest. Recommended for reviewers. |
| `acceptEdits` | Auto-accepts file edits | Good for execution agents. |
| `delegate` | Coordination-only | For agent team leads. |
| `dontAsk` | Auto-denies permission prompts | Explicitly allowed tools still work. |
| `bypassPermissions` | Skips all permission checks | High risk. Only for CI/automation. |
| `plan` | Read-only exploration | For planning/research agents. |

### `maxTurns` Guidance

Use `maxTurns` to bound runaway execution. Useful for review agents (where a bounded check is sufficient) and CI agents (where infinite loops are costly). Omit for execution agents that need flexibility to complete complex implementations.

### `memory` Scopes

| Scope | Persists Across | Use Case |
|-------|-----------------|----------|
| `user` | All projects for this user | Personal preferences, global patterns |
| `project` | All sessions in this project | Project conventions, settled decisions |
| `local` | Local machine only | Machine-specific configuration |

### Complex Fields

**`hooks`**: Lifecycle hooks triggered by agent events (e.g., `PostToolUse`, `PreToolUse`). See [official Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for hook configuration syntax.

**`mcpServers`**: MCP server configurations scoped to this agent. Same syntax as project-level `.claude/settings.json` MCP configuration. See [MCP documentation](https://modelcontextprotocol.io/) for server setup.

---

## Tool Configuration Patterns

The `tools` field distinguishes agent capabilities:

| Pattern | Tools | Use Case |
|---------|-------|----------|
| Review-only | `Read, Grep, Glob, SendMessage, TaskUpdate, TaskList` | Agents that inspect code but never modify it. Safer for adversarial review dispatch. |
| Execution-capable | `Read, Grep, Glob, Bash, Write, Edit, SendMessage, TaskUpdate, TaskList` | Agents that implement changes. Used by `/coding-workflows:execute-issue` for TDD loops. |
| Full access | *(omit field)* | Inherits all available tools. Suitable for general-purpose agents. |
| Everything except | *(omit `tools`)* + `disallowedTools: Write, Edit` | "All tools except these." Cleaner than verbose allowlists. |

**`tools` and `disallowedTools` interaction:** When both are specified, `disallowedTools` removes tools from the `tools` list. When only `disallowedTools` is specified (no `tools` field), it removes from inherited tools. This lets you express "everything except X" without listing every tool.

**Why Bash matters:** Including `Bash` grants shell execution capability (running tests, linters, build commands). Review-only agents intentionally omit `Bash` (and `Write`/`Edit`) to ensure they can only observe, not modify. This is a trust boundary, not just a convenience.

**Anti-pattern:** Do not include `Bash` on review-only agents "just in case." If an agent's role is `reviewer`, its tool set should reflect read-only access unless the review workflow requires running tests or linters.

---

## Plugin Extension Fields

These fields are read by the plugin's workflow commands (agent discovery, generation, staleness detection), not by the Claude Code runtime.

### Discovery Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `domains` | list[string] | `[]` | Keywords this agent covers. Used for matching against issue content. |
| `role` | string | `specialist` | One of: `specialist`, `reviewer`, `architect`. Affects dispatch priority. |

#### Role Semantics

| Role | Dispatch Behavior |
|------|-------------------|
| `specialist` | Invoked when issue keywords match domains. Standard input weight. |
| `reviewer` | Invoked for code review and plan critique. May be dispatched adversarially. |
| `architect` | Invoked for cross-cutting concerns. Higher authority in conflict resolution. |

### Provenance Fields -- Agents and Skills

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
skills: [plugin:coding-workflows:knowledge-freshness, billing-patterns, plugin:coding-workflows:issue-workflow]
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

See `references/agent-template.md` for a complete agent file template with all sections. Read it when creating a new agent or reviewing agent file completeness.

---

## What Makes Agents Effective

**High-value content:** Project-specific conventions not in CLAUDE.md, settled decisions that should never be re-debated, common codebase gotchas, review checklists tuned to actual past issues.

**Low-value content:** Generic language/framework advice (Claude already knows this), copy-pasted library docs, overly broad domain coverage, implementation instructions (agents review, they don't implement).

Generated agents from `/coding-workflows:generate-assets` provide scaffolding. Hand-edit them with project-specific knowledge for significantly better results.

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
