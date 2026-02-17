# coding-workflows

Engineering workflow commands for Claude Code. Plan, review, and execute GitHub issues with dynamically discovered specialist agents.

Commands define **what** to do. Skills provide **patterns and knowledge**. Hooks enforce **workflow rules** automatically.

## Quick Start

```bash
# Install
/plugin marketplace add Kiwi-Home/ai-coding-resources
/plugin install coding-workflows@ai-coding-resources

# Turn a vague idea into a structured issue
/coding-workflows:create-issue github "users can't reset their password if they signed up with SSO"

# Run the full pipeline on an issue
/coding-workflows:prepare-issue 42

# Execute the reviewed plan
/coding-workflows:execute-issue 42
```

The plugin auto-detects your project settings. For full project initialisation (config, agents, skills): `/coding-workflows:setup`.

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- Git repository with a GitHub remote

## How It Works

```
/prepare-issue 42
     │
     ├─ Complexity triage (solo / lightweight / full)
     │
     ├─ Design session (3-4 specialists, conflict resolution)
     │
     ├─ Implementation plan (codebase exploration, build-vs-buy)
     │
     └─ Adversarial review (blocks until plan passes)

/execute-issue 42
     │
     ├─ Verifies reviewed plan exists
     │
     ├─ Creates feature branch
     │
     ├─ TDD implementation with verification gates
     │
     └─ Opens PR, runs review loop
```

## Getting Started

### Tier 1: Zero Config

Install and run. Project settings (org, repo, language, test commands) are auto-detected from your git remote and project files.

### Tier 2: Configured

Run `/coding-workflows:init-config` to generate `.claude/workflow.yaml` with your test, lint, typecheck, and branch pattern settings. Commands read this config instead of auto-detecting.

### Tier 3: Full Setup

Run `/coding-workflows:setup` for unified project initialisation:

1. CLAUDE.md check (project context)
2. `workflow.yaml` generation (configuration)
3. Project-specific skills (conventions and patterns from your codebase)
4. Project-specific agents (specialist expertise with cross-referenced skills)

## Command Reference

### The Pipeline

| Command | What It Does |
|---------|--------------|
| `/coding-workflows:create-issue <platform> <desc>` | Create a well-structured issue on GitHub (best-effort: Linear, Jira, Asana) |
| `/coding-workflows:prepare-issue <issue> [mode]` | Full preparation pipeline with complexity triage |
| `/coding-workflows:execute-issue <issue>` | Implement a planned+reviewed issue using TDD; creates feature branch, opens PR, and manages review loop (up to 3 iterations) |
| `/coding-workflows:execute-issue-worktree <issue>` | Execute a planned+reviewed issue in an isolated git worktree |

### Building Blocks

Use these individually when you don't need the full pipeline:

| Command | What It Does |
|---------|--------------|
| `/coding-workflows:design-session <subject>` | Run a technical design session on an issue, PR, file, or topic with dynamically discovered specialist agents |
| `/coding-workflows:plan-issue <issue>` | Draft a specialist-reviewed implementation plan (honors prior design-session decisions) |
| `/coding-workflows:review-plan <issue>` | Adversarial review of an implementation plan; posts revised plan if blocking issues found |
| `/coding-workflows:review-pr <pr>` | Review a pull request for quality, compliance, and merge readiness using severity-tiered findings |

### Setup & Maintenance

| Command | What It Does |
|---------|--------------|
| `/coding-workflows:setup` | Unified idempotent project initialization -- CLAUDE.md, config, agents, skills, and hooks |
| `/coding-workflows:init-config` | Bootstrap workflow.yaml by auto-detecting project settings |
| `/coding-workflows:generate-assets [mode]` | Generate project-specific agents and skills by scanning the codebase |
| `/coding-workflows:merge-issue <issue>` | Merge a PR and clean up branch + worktree for a completed issue |
| `/coding-workflows:cleanup-worktree <issue>` | Remove worktree and branch for a completed issue; idempotent with unmerged-changes safety check |
| `/coding-workflows:check-updates [sources]` | Check upstream dependencies for new releases and changelog updates; produces a local markdown digest with change tiers |
| `/coding-workflows:help` | Reference guide for coding workflow commands, concepts, and adoption |

> **Auto-posting:** `plan-issue`, `review-plan`, `review-pr`, `design-session`, and `prepare-issue` post comments to GitHub automatically. `create-issue` posts to the user's chosen platform. Review the output after it's posted.

> **Plan gate:** `execute-issue` verifies a reviewed plan exists before starting. If none is found, it directs you to run `plan-issue` first.

## Skill Reference

Skills auto-activate based on context. Manual invocation: `/coding-workflows:<skill-name>`.

### Workflow Skills

| Skill | Purpose |
|-------|---------|
| `issue-workflow` | Structured workflow for planning and executing GitHub issues |
| `issue-writer` | Writes requirements-focused issues that describe what needs to be done, not how to implement it |
| `complexity-triage` | Complexity assessment framework for routing issues to appropriate preparation depth |
| `deliberation-protocol` | Governs multi-round specialist deliberation for design sessions, plan reviews, and adversarial dispatch |
| `agent-team-protocol` | Governs parallel code execution teams with file ownership, TDD workflow, git coordination, and team lifecycle management |
| `project-context` | Shared context-resolution pattern for workflow commands |

### Knowledge Skills

| Skill | Purpose |
|-------|---------|
| `tdd-patterns` | Stack-aware TDD patterns, anti-patterns, and quality heuristics |
| `systematic-debugging` | Structured debugging methodology for hypothesis-driven failure resolution |
| `pr-review` | Framework for reviewing pull requests with severity-tiered findings, ecosystem-adapted focus areas, and strict exit criteria |
| `security-patterns` | Security detection patterns, anti-patterns, and OWASP mapping for code review |
| `refactoring-patterns` | Safe refactoring patterns for AI-assisted development |
| `knowledge-freshness` | Staleness triage framework for evaluating when training data is reliable vs. when verification is required |

### Asset Management Skills

| Skill | Purpose |
|-------|---------|
| `skill-creator` | Guides creation of effective skills that extend Claude with specialized knowledge, workflows, or tool integrations |
| `agent-patterns` | Documents agent frontmatter metadata spec and patterns for creating effective project-specific agents |
| `asset-discovery` | Discovers existing skills and agents across project, user, and plugin layers and provides similarity heuristics for detecting overlapping assets |
| `stack-detection` | Technology stack detection reference tables and per-stack analysis guidance |
| `codebase-analysis` | Criteria for analyzing codebases to inform agent and skill generation |

## Shipped Hooks

Hooks activate on install — no configuration needed.

| Hook | Event | Behaviour |
|------|-------|-----------|
| `check-dependency-version` | PreToolUse | Warns when dependency-add commands lack version pins |
| `pre-push-verification` | PreToolUse | Blocks git push without passing test/lint evidence |
| `test-evidence-logger` | PostToolUse | Logs test/lint evidence to session trail |
| `checkpoint-staleness` | PostToolUse | Prompts session checkpoints during extended execute-issue work |
| `deferred-work-scanner` | PostToolUse | Scans PR body for untracked deferrals |
| `stop-deferred-work-check` | Stop | Warns about deferred work without follow-up issues |
| `execute-issue-completion-gate` | Stop | Prevents premature exit with incomplete CI checks |
| `check-agent-output-completeness` | SubagentStop | Validates subagent output contains expected sections |

Disable any hook with an environment variable:

```bash
export CODING_WORKFLOWS_DISABLE_HOOK_DEPENDENCY_VERSION_CHECK=1
export CODING_WORKFLOWS_DISABLE_HOOK_TEST_EVIDENCE_LOGGER=1
# ... see Configuration Reference for the full list
```

Or configure via `workflow.yaml`:

```yaml
hooks:
  check_dependency_version:
    mode: block              # Switch from advisory to blocking
  execute_issue_completion_gate:
    review_gate: true        # Enable review verdict polling
    escalation_threshold: 5  # Override blocked-stop threshold
```

Plugin hooks merge with your user-level hooks and run in parallel — they never replace or conflict with user hooks.

## Configuration Reference

Configuration lives in `.claude/workflow.yaml`. Run `/coding-workflows:init-config` to generate it.

| Section | Purpose |
|---------|---------|
| `project` | Repo identity: org, name, language, git provider |
| `commands` | Test (focused + full), lint, typecheck, branch pattern |
| `planning` | Always-include agents, reference docs |
| `deliberation` | Conflict overrides for multi-round specialist dispatch |
| `hooks` | Hook behaviour overrides |

See `templates/workflow.yaml` for the full schema with examples for Python, JavaScript, Rust, Go, and Ruby.

## Agent Discovery

Commands discover agents by scanning `.claude/agents/*.md` and reading YAML frontmatter:

- `domains` — keywords for matching (e.g., `[api, routes, async]`)
- `role` — `specialist`, `reviewer`, or `architect`

Commands match agents to workflow phases: domain specialists during planning, reviewers during PR review, TDD-focused agents during execution. See `coding-workflows:agent-patterns` for the full metadata spec.

## CI Review Setup

The `review-pr` command works identically from CLI and CI. To automate it on every pull request, create `.github/workflows/pr-review.yml`:

```yaml
name: PR Review
on:
  pull_request:
    types: [opened, synchronize, ready_for_review, reopened]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: write
      actions: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          allowed_bots: 'claude[bot]'
          track_progress: false
          use_sticky_comment: false
          claude_args: |
            --allowedTools "Read,Grep,Glob,Bash(gh issue create:*),Bash(gh issue view:*),Bash(gh label create:*),Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}
            You have the coding-workflows plugin installed.
            Run the /coding-workflows:review-pr command for PR ${{ github.event.pull_request.number }}.
            Use the REPO and PR NUMBER above for all operations.
```

**Required secrets:** `CLAUDE_CODE_OAUTH_TOKEN` — see the [claude-code-action setup guide](https://github.com/anthropics/claude-code-action).

**Permissions:** `issues: write` enables the CREATE ISSUE protocol for follow-up issues. Without it, reviews still post but follow-up issues fail silently.

**Iteration behaviour:** Iterations 1-3 run comprehensive reviews. Iterations 4+ switch to verification mode (only checks previous MUST FIX items).

**Project-specific focus:** Run `/coding-workflows:generate-assets review-config` to generate `.claude/review-config.yaml` with project-specific review criteria. The command reads it automatically in both CLI and CI.

For advanced CI configuration (inline fallback rules, path filters, allowed tools detail), see the [CI deep dive](docs/ci-review.md).

## Customisation

Override any command by placing a same-named file in `.claude/commands/`. Claude Code's local-wins precedence means your version shadows the plugin version automatically.

## Experimental: Agent Teams

Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to enable parallel agent execution during implementation. When enabled, `execute-issue` can dispatch independent layers to parallel agents. When not set, all commands use sequential dispatch.

## FAQ

**`prepare-issue` vs `plan-issue`?** `prepare-issue` runs the full pipeline (triage → design → plan → review). `plan-issue` skips design and goes straight to planning. Use `prepare-issue` for raw issues; `plan-issue` when design decisions are already clear.

**`init-config` vs `generate-assets` vs `setup`?** `init-config` creates workflow.yaml only. `generate-assets` generates agents/skills from a codebase scan. `setup` does everything in one pass. Use `setup` for initial onboarding.

**CLI review vs CI review?** Same command, same skill. `/review-pr <pr>` from the terminal, or automate via GitHub Actions. See [CI Review Setup](#ci-review-setup).

**Do I need agents?** No. All commands work without agents. Agents enhance design sessions and reviews with project-specific expertise but are entirely optional.

**Is `setup` safe to re-run?** Yes. It's idempotent. Existing files are preserved. Stale config is detected and offered for update.

**How do I customise a command?** Copy it to `.claude/commands/` with the same filename. Your version takes precedence.

## Troubleshooting

**`gh` not found** — Install: `brew install gh` (macOS) or [cli.github.com](https://cli.github.com). Authenticate: `gh auth login`.

**No plan found** — `execute-issue` requires a plan comment on the issue. Run `plan-issue` first.

**Settings confirmation keeps appearing** — Create persistent config: `/coding-workflows:init-config`.

**CI review posts no comment** — Check `CLAUDE_CODE_OAUTH_TOKEN` secret and `pull-requests: write` permission.

**CI follow-up issues not created** — Add `issues: write` to the workflow permissions.

## License

MIT
