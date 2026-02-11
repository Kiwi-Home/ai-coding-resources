---
description: Quick reference for all coding workflow commands
allowed-tools:
  - Read
  - Grep
  - Glob
---

# Help

## Commands

| Command | Description |
|---------|-------------|
| `/coding-workflows:init-config` | Bootstrap workflow.yaml by auto-detecting project settings |
| `/coding-workflows:generate-assets [mode]` | Generate project-specific agents and skills by scanning the codebase |
| `/coding-workflows:setup` | Unified idempotent project initialization -- CLAUDE.md, config, agents, skills, and hooks |
| `/coding-workflows:help` | Quick reference for all coding workflow commands |
| `/coding-workflows:create-issue <platform> <desc>` | Create a well-structured issue in your tracker (GitHub, Linear, Jira, Asana)\* |
| `/coding-workflows:design-session <subject>` | Run a technical design session on an issue, PR, file, or topic with dynamically discovered specialist agents |
| `/coding-workflows:plan-issue <issue>` | Draft a specialist-reviewed implementation plan (honors prior design-session decisions), then auto-chain into adversarial review |
| `/coding-workflows:review-plan <issue>` | Adversarial review of an implementation plan; posts revised plan if blocking issues found |
| `/coding-workflows:review-pr <pr>` | Review a pull request for quality, compliance, and merge readiness using severity-tiered findings |
| `/coding-workflows:execute-issue <issue>` | Implement a planned+reviewed issue using TDD; creates feature branch, opens PR, and manages review loop (up to 3 iterations) |
| `/coding-workflows:prepare-issue <issue>` | Full preparation pipeline - design session, plan, review, revised plan. Stops for human approval before execution. |

\* `/coding-workflows:create-issue` operates independently of `workflow.yaml` configuration.

## Typical Workflow

Quick start (recommended):
```
1. /coding-workflows:setup                             # Project initialization (idempotent -- re-run to keep agents and skills in sync as codebase evolves)
2. /coding-workflows:create-issue github <desc>       # Create an issue
3. /coding-workflows:prepare-issue <issue>            # Design + plan + review
4. /coding-workflows:execute-issue <issue>            # Implement with TDD
```

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
| `coding-workflows:deliberation-protocol` | Governs multi-round specialist deliberation for design sessions, plan reviews, and adversarial dispatch |
| `coding-workflows:issue-workflow` | Structured workflow for planning and executing GitHub issues |
| `coding-workflows:issue-writer` | Writes requirements-focused issues that describe what needs to be done, not how to implement it. Works with any tracker (GitHub, Linear, Jira, Asana). |
| `coding-workflows:pr-review` | Framework for reviewing pull requests with severity-tiered findings, ecosystem-adapted focus areas, and strict exit criteria |
| `coding-workflows:stack-detection` | Technology stack detection reference tables and per-stack analysis guidance. Maps project files to languages, dependencies to frameworks, and directory structures to domains |
| `coding-workflows:systematic-debugging` | Structured debugging methodology for hypothesis-driven failure resolution. Encodes failure classification, evidence hierarchy, hypothesis quality criteria, and escalation thresholds |
| `coding-workflows:tdd-patterns` | Stack-aware TDD patterns, anti-patterns, and quality heuristics for test-driven development |

## Progressive Disclosure

| Tier | Setup | Capabilities |
|------|-------|-------------|
| **Zero Config** | Install plugin, run any command | Auto-detected settings, no specialist agents, solo operation |
| **Configured** | Run `/coding-workflows:init-config` | Custom test/lint commands, branch patterns, org/repo defaults |
| **Full Setup** | Run `/coding-workflows:setup` | CLAUDE.md check, workflow.yaml, project-specific agents and skills, conflict matrix, plugin hooks active |
