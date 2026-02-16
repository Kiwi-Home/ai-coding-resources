---
description: Reference guide for coding workflow commands, concepts, and adoption
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Help

## Concepts

The plugin has four building blocks:

- **Commands** — User-facing actions you invoke (e.g., `/coding-workflows:plan-issue`). They orchestrate workflows by reading skills and dispatching agents.
- **Skills** — Reusable knowledge and patterns. Auto-activated based on context — they teach Claude how to approach a domain (e.g., TDD patterns, issue writing conventions).
- **Agents** — Project-specific specialists generated from your codebase. Commands discover and dispatch them dynamically for design sessions, planning, and reviews. Optional — all commands work without agents.
- **Hooks** — Lifecycle rules that enforce workflow discipline automatically (e.g., version pinning, test evidence logging). Active on plugin install — no configuration needed.

## Commands

### Setup

| Command | Description |
|---------|-------------|
| `/coding-workflows:init-config` | Bootstrap workflow.yaml by auto-detecting project settings |
| `/coding-workflows:generate-assets [mode]` | Generate project-specific agents and skills by scanning the codebase |
| `/coding-workflows:setup` | Unified idempotent project initialization -- CLAUDE.md, config, agents, skills, and hooks |
| `/coding-workflows:help` | Reference guide for coding workflow commands, concepts, and adoption |

### Issue Management

| Command | Description |
|---------|-------------|
| `/coding-workflows:create-issue <platform> <desc>` | Create a well-structured issue on GitHub (best-effort: Linear, Jira, Asana)\* |

\* `/coding-workflows:create-issue` validates `git_provider` only for the `github` platform; other platforms skip this check.

### Pipeline

| Command | Description |
|---------|-------------|
| `/coding-workflows:prepare-issue <issue> [mode]` | Full preparation pipeline with complexity triage. Routes to solo, lightweight, or full design session based on issue complexity (or explicit mode), then plan + review. Stops for human approval before execution. |

### Building Blocks

| Command | Description |
|---------|-------------|
| `/coding-workflows:design-session <subject>` | Run a technical design session on an issue, PR, file, or topic with dynamically discovered specialist agents |
| `/coding-workflows:plan-issue <issue>` | Draft a specialist-reviewed implementation plan (honors prior design-session decisions), then auto-chain into adversarial review |
| `/coding-workflows:review-plan <issue>` | Adversarial review of an implementation plan; posts revised plan if blocking issues found |
| `/coding-workflows:review-pr <pr>` | Review a pull request for quality, compliance, and merge readiness using severity-tiered findings |
| `/coding-workflows:execute-issue <issue>` | Implement a planned+reviewed issue using TDD; creates feature branch, opens PR, and manages review loop (up to 3 iterations) |
| `/coding-workflows:execute-issue-worktree <issue>` | Execute a planned+reviewed issue in an isolated git worktree. Creates worktree, implements changes, commits, pushes, and creates PR. Use AFTER planning is complete. |

### Maintenance

| Command | Description |
|---------|-------------|
| `/coding-workflows:merge-issue <issue>` | Merge a PR and clean up branch + worktree for a completed issue |
| `/coding-workflows:cleanup-worktree <issue>` | Remove worktree and branch for a completed issue; idempotent with unmerged-changes safety check |
| `/coding-workflows:check-updates [sources]` | Check upstream dependencies for new releases and changelog updates; produces a local markdown digest with change tiers |

## Typical Workflow

Quick start (recommended):

```
1. /coding-workflows:setup                             # One-time: generates config, agents, skills
```
Scans your codebase and creates `.claude/workflow.yaml` + project-specific agents and skills. Idempotent — re-run to keep agents and skills in sync as the codebase evolves.

```
2. /coding-workflows:create-issue github <desc>       # Creates structured GitHub issue
```
Transforms a description into a requirements-focused issue and posts it to GitHub.

```
3. /coding-workflows:prepare-issue <issue>            # Design + plan + review
```
Runs complexity triage, design session, implementation plan, and adversarial review. Posts all artifacts to the issue. Review the plan, then approve.

```
4. /coding-workflows:execute-issue <issue>            # Implement with TDD
```
Creates a feature branch, implements per plan, and opens a PR. CI runs automatically; the review loop iterates up to 3 times.

```
5. /coding-workflows:merge-issue <issue>              # Merge PR + clean up
```
Merges the PR and removes the feature branch (after human approval).

Granular control over setup:
```
1. /coding-workflows:init-config                      # Create workflow.yaml only
2. /coding-workflows:generate-assets                  # Generate both agents and skills
3. /coding-workflows:generate-assets agents            # Generate agents only
4. /coding-workflows:generate-assets skills            # Generate skills only
5. /coding-workflows:generate-assets review-config     # Generate project-specific review focus
6. /coding-workflows:generate-assets all               # Generate skills, agents, and review config
```

For simpler tasks:
```
1. /coding-workflows:plan-issue <issue>               # Plan + auto-review
2. /coding-workflows:execute-issue <issue>            # Implement
```

## Adoption Path

| Tier | Setup | Capabilities | Try First |
|------|-------|-------------|-----------|
| **Zero Config** | Install plugin, run any command | Auto-detected settings, no specialist agents, solo operation | `/coding-workflows:plan-issue` on any issue |
| **Configured** | Run `/coding-workflows:init-config` | Custom test/lint commands, branch patterns, org/repo defaults | `/coding-workflows:execute-issue` — TDD loop runs your configured tests |
| **Full Setup** | Run `/coding-workflows:setup` | CLAUDE.md check, workflow.yaml, project-specific agents and skills, conflict matrix, plugin hooks active | `/coding-workflows:prepare-issue` with specialist agents |

**Entry point:** Zero Config — install the plugin and run any command. No setup required.

**Recommended upgrade:** Run `/coding-workflows:setup` when you want project-specific agents and specialist dispatch in design sessions.

## Current Configuration

To check your configuration status, read `.claude/workflow.yaml`. If no config exists, commands will auto-detect settings and confirm with you.

## Discovered Agents

To see what agents are available, check `.claude/agents/*.md`. Each agent file has frontmatter with `name`, `domains`, and `role` that workflow commands use for dynamic dispatch.

## Skills

| Skill | Description |
|-------|-------------|
| `coding-workflows:agent-patterns` | Documents agent frontmatter metadata spec and patterns for creating effective project-specific agents |
| `coding-workflows:agent-team-protocol` | Governs parallel code execution teams with file ownership, TDD workflow, git coordination, and team lifecycle management |
| `coding-workflows:asset-discovery` | Discovers existing skills and agents across project, user, and plugin layers and provides similarity heuristics for detecting overlapping assets |
| `coding-workflows:codebase-analysis` | Criteria for analyzing codebases to inform agent and skill generation |
| `coding-workflows:complexity-triage` | Complexity assessment framework for routing issues to appropriate preparation depth. Defines triage signals, mode selection criteria, and output templates for solo and lightweight modes. Referenced by prepare-issue before design session dispatch. |
| `coding-workflows:deliberation-protocol` | Governs multi-round specialist deliberation for design sessions, plan reviews, and adversarial dispatch |
| `coding-workflows:issue-workflow` | Structured workflow for planning and executing GitHub issues |
| `coding-workflows:issue-writer` | Writes requirements-focused issues that describe what needs to be done, not how to implement it. Works with any tracker. |
| `coding-workflows:knowledge-freshness` | Staleness triage framework for evaluating when training data is reliable vs. when verification is required |
| `coding-workflows:pr-review` | Framework for reviewing pull requests with severity-tiered findings, ecosystem-adapted focus areas, and strict exit criteria |
| `coding-workflows:project-context` | Shared context-resolution pattern for workflow commands |
| `coding-workflows:refactoring-patterns` | Safe refactoring patterns for AI-assisted development |
| `coding-workflows:security-patterns` | Security detection patterns, anti-patterns, and OWASP mapping for code review |
| `coding-workflows:skill-creator` | Guides creation of effective skills that extend Claude with specialized knowledge, workflows, or tool integrations. Covers skill anatomy, frontmatter fields, bundled resources, progressive disclosure, and the init/edit/package lifecycle. Use when: creating a new skill, updating an existing skill, understanding skill structure, or packaging skills for distribution. |
| `coding-workflows:stack-detection` | Technology stack detection reference tables and per-stack analysis guidance. Maps project files to languages, dependencies to frameworks, and directory structures to domains |
| `coding-workflows:systematic-debugging` | Structured debugging methodology for hypothesis-driven failure resolution. Encodes failure classification, evidence hierarchy, hypothesis quality criteria, and escalation thresholds |
| `coding-workflows:tdd-patterns` | Stack-aware TDD patterns, anti-patterns, and quality heuristics for test-driven development |
