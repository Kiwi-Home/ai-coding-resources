# Agent Generation Spec

Template and examples for generating project-specific agent files via `generate-assets`. For manual agent creation, see `agent-template.md` instead.

## Pre-population Sources

| Section | Analysis Path | Fallback Path | Minimal Context |
|---------|---------------|---------------|-----------------|
| `name` | Domain-specific from analysis | Generic from `coding-workflows:stack-detection` table | Generic from `coding-workflows:stack-detection` table |
| `description` | Feature-specific with library names | Framework-level | Framework-level |
| `domains` | Analysis-detected keywords | `coding-workflows:stack-detection` domain keyword table | `coding-workflows:stack-detection` domain keyword table |
| `skills` | Confirmed/generated skills matching domain + existing plugin skills | Existing plugin skill references only | Existing plugin skill references only |
| Project Conventions | 2-3 observed patterns with file citations | TODO block | TODO block (current scaffolding) |
| Settled Decisions | From CLAUDE.md quotes only | TODO block | TODO block (current scaffolding) |
| Review Checklist | Domain-specific items from codebase patterns + research | Generic framework items | Generic items (current scaffolding) |
| Skills Referenced | Matching project + plugin skills (markdown section) | Plugin skill references only | Plugin skill references only |

TODOs only for: edge cases requiring human judgment, production-specific knowledge not visible in code, areas where research was declined.

## Evidence Citations

When pre-populating conventions, cite evidence:
- File paths: `src/billing/webhooks.py`
- Pattern coverage: `app/jobs/*.rb (12 files matching pattern)`
- Always include at least one concrete file path per convention -- never just counts

## Conditional Field Omission

The `model` and `maxTurns` fields are only written when the role-based default is NOT *(omit)* (see `role-defaults.md`). When *(omit)*, omit the entire line from the generated file (do not write the key at all). See the rendered examples below for correct output per role.

## Agent Template

```markdown
---
name: {domain}-{role}
description: "Reviews {domain} code for {framework} patterns and project conventions"
tools: {role_tools}
model: {role_model}
permissionMode: default
maxTurns: {role_maxTurns}
color: {role_color}
domains: [{domain keywords}]
# NOTE: skills listed here are fully injected into agent context at startup.
# This consumes context tokens (~5,000 token aggregate budget recommended).
# Universal skills (conditional on execution capability):
#   - plugin:coding-workflows:knowledge-freshness (~1,273 tokens)
#     Include when: agent has Write OR Edit tools (execution-capable)
#     Omit when: agent has neither Write nor Edit (review-only)
# Budget: ~3,727 remaining for execution-capable, ~5,000 for review-only.
skills: [{if has Write/Edit: plugin:coding-workflows:knowledge-freshness,} {matching domain skill names}]
role: {role}
generated_by: generate-assets
generated_at: "{YYYY-MM-DD}"
---

# {Domain} {Role_capitalized}

## Your Role
{role_description}

## Project Conventions
{analysis_path: 2-3 observed patterns with file path citations}
{fallback_path: TODO block with guidance comments}

## Settled Decisions
Decisions that are NOT up for debate:
{analysis_path: 1-2 decisions quoted from CLAUDE.md with citations}
{fallback_path: TODO block}

## Review Checklist
{analysis_path: domain-specific items from codebase patterns}
{fallback_path: generic items}
- [ ] Follows project naming conventions
- [ ] Error handling is consistent with project patterns
- [ ] Tests cover happy path and error cases
- [ ] No security issues (input validation, data exposure)

## Skills You Should Reference
The following skills provide relevant patterns (informational -- they are NOT
auto-injected unless also listed in frontmatter `skills:` above):
{analysis_path: matching project + plugin skills with brief context}
{fallback_path: matching plugin skills only}
```

## Rendered Examples (Frontmatter Only)

The body structure (Your Role, Project Conventions, Settled Decisions, Review Checklist, Skills You Should Reference) is role-independent -- see the Agent Template above. The frontmatter varies by role.

### Reviewer (`api-reviewer.md`)

```yaml
---
name: api-reviewer
description: "Reviews API code for FastAPI patterns and project conventions"
tools: Read, Grep, Glob, SendMessage, TaskUpdate, TaskList
model: sonnet
permissionMode: default
maxTurns: 50
color: blue
domains: [api, routes, endpoints, http, middleware]
# No universal skills (review-only, no Write/Edit). Domain: api-patterns.
skills: [api-patterns]
role: reviewer
generated_by: generate-assets
generated_at: "2026-02-13"
---
```

### Architect (`infra-architect.md`)

```yaml
---
name: infra-architect
description: "Reviews infrastructure code for deployment patterns and project conventions"
tools: Read, Grep, Glob, Bash, SendMessage, TaskUpdate, TaskList
permissionMode: default
maxTurns: 75
color: purple
domains: [deploy, ci, docker, infrastructure, config]
# No universal skills (review-only, no Write/Edit).
skills: []
role: architect
generated_by: generate-assets
generated_at: "2026-02-13"
---
```

Note: `model` line is absent (inherits from parent context).

### Specialist (`billing-specialist.md`)

```yaml
---
name: billing-specialist
description: "Reviews billing code for Stripe patterns and project conventions"
tools: Read, Grep, Glob, Bash, Write, Edit, SendMessage, TaskUpdate, TaskList
permissionMode: default
color: green
domains: [billing, payments, stripe, webhooks]
# Universal (execution-capable, has Write/Edit): knowledge-freshness. Domain: billing-patterns.
skills: [plugin:coding-workflows:knowledge-freshness, billing-patterns]
role: specialist
generated_by: generate-assets
generated_at: "2026-02-13"
---
```

Note: both `model` and `maxTurns` lines are absent.

### `tools` Field Note

The `tools` field is role-dependent (see `role-defaults.md` for Role-Based Tool Sets). Reviewer agents are restricted to read-only tools as a trust boundary. Architect agents add `Bash` for shell execution. Specialist agents add `Bash`, `Write`, and `Edit` for full implementation capability. All roles include `SendMessage`, `TaskUpdate`, and `TaskList` for team coordination. See `coding-workflows:agent-patterns` for tool configuration patterns.

## Domain-Specific Keywords

| Domain | Example `domains` array |
|--------|------------------------|
| API | `[api, routes, endpoints, http, middleware, handlers]` |
| Storage | `[storage, database, schema, queries, migrations, models]` |
| Auth | `[auth, authentication, authorization, security, sessions]` |
| Business Logic | `[services, business-logic, use-cases, operations]` |
| Testing | `[testing, tdd, coverage, fixtures, mocks]` |
| Infrastructure | `[deploy, ci, docker, infrastructure, config]` |
