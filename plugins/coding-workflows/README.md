# Coding Workflows Plugin

Engineering workflow commands for planning, reviewing, and executing GitHub issues with dynamically discovered specialist agents.

Commands define **what** to do. Skills provide the **patterns and knowledge**.

## Quick Start

```bash
claude plugin install coding-workflows@ai-coding-resources

# Plan and review an issue
/coding-workflows:prepare-issue 42

# Execute the reviewed plan
/coding-workflows:execute-issue 42
```

That's it. The plugin auto-detects your project settings.

For full project initialization (config, agents, skills):

```bash
/coding-workflows:setup
```

### Which command should I run?

```
Install plugin
     |
     v
Do you want custom config? --no--> /coding-workflows:create-issue github <desc>
     |                                    |
    yes                                   v
     |                              /coding-workflows:prepare-issue <issue>
     v                                    |
/coding-workflows:setup                   v
     |                              /coding-workflows:execute-issue <issue>
     v
/coding-workflows:create-issue github <desc>
     |
     v
/coding-workflows:prepare-issue <issue>
     |
     v
/coding-workflows:execute-issue <issue>
```

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- Git repository with a GitHub remote
- v3 supports GitHub only

## Installation

```bash
claude plugin install coding-workflows@ai-coding-resources
```

## Getting Started

### Tier 1: Zero Config

Install the plugin and run any command. Project settings (org, repo, language, test commands) are auto-detected from your git remote and project files.

If auto-detection gets something wrong, you'll be asked to confirm before proceeding.

*Ready for more control? Move to Tier 2.*

### Tier 2: Configured

Run `/coding-workflows:init-config` to generate `.claude/workflow.yaml` with your project's test, lint, typecheck, and branch pattern settings. Commands read this config instead of auto-detecting.

See [Configuration Reference](#configuration-reference) for the full schema.

*Want specialist design sessions? Move to Tier 3.*

### Tier 3: Full Setup

Run `/coding-workflows:setup` for unified project initialization. This command orchestrates everything in one pass:

1. CLAUDE.md check (project context)
2. `workflow.yaml` generation (configuration)
3. Project-specific skills (conventions and patterns)
4. Project-specific agents (specialist expertise, with `skills:` cross-references)

Or use `/coding-workflows:generate-assets` for finer control:
- `/coding-workflows:generate-assets` -- generate both skills and agents
- `/coding-workflows:generate-assets skills` -- generate skills only
- `/coding-workflows:generate-assets agents` -- generate agents only
- `/coding-workflows:generate-assets review-config` -- generate project-specific review focus areas
- `/coding-workflows:generate-assets all` -- generate skills, agents, and review config

Commands orchestrate the workflow. Skills teach the knowledge. Agents bring project-specific expertise.

## Command Reference

### Setup

| Command | Description |
|---------|-------------|
| `/coding-workflows:init-config` | Bootstrap workflow.yaml by auto-detecting project settings |
| `/coding-workflows:generate-assets [mode]` | Generate project-specific agents and skills by scanning the codebase |
| `/coding-workflows:setup` | Unified idempotent project initialization -- CLAUDE.md, config, agents, skills, and hooks |
| `/coding-workflows:help` | Quick reference for all coding workflow commands |

### Issue Management

| Command | Description |
|---------|-------------|
| `/coding-workflows:create-issue <platform> <desc>` | Create a well-structured issue in your tracker (GitHub, Linear, Jira, Asana)\* |

\* `/coding-workflows:create-issue` operates independently of `workflow.yaml` configuration.

### Pipeline

| Command | Description |
|---------|-------------|
| `/coding-workflows:prepare-issue <issue>` | Full preparation pipeline - design session, plan, review, revised plan. Stops for human approval before execution. |

### Building Blocks

| Command | Description |
|---------|-------------|
| `/coding-workflows:design-session <subject>` | Run a technical design session on an issue, PR, file, or topic with dynamically discovered specialist agents |
| `/coding-workflows:plan-issue <issue>` | Draft a specialist-reviewed implementation plan (honors prior design-session decisions), then auto-chain into adversarial review |
| `/coding-workflows:review-plan <issue>` | Adversarial review of an implementation plan; posts revised plan if blocking issues found |
| `/coding-workflows:review-pr <pr>` | Review a pull request for quality, compliance, and merge readiness using severity-tiered findings |
| `/coding-workflows:execute-issue <issue>` | Implement a planned+reviewed issue using TDD; creates feature branch, opens PR, and manages review loop (up to 3 iterations) |

> **Important:** `/coding-workflows:plan-issue`, `/coding-workflows:review-plan`, `/coding-workflows:review-pr`, `/coding-workflows:design-session`, `/coding-workflows:create-issue`, and `/coding-workflows:prepare-issue` post comments or issues to GitHub automatically without prompting for confirmation. Review the output on the issue or PR after it's posted.

> **Note:** `/coding-workflows:execute-issue` verifies a reviewed plan exists before starting. If no plan is found, it stops and directs you to run `/coding-workflows:plan-issue` first.

## Skill Reference

Skills auto-activate based on context (triggers and domains in frontmatter). Manual invocation uses the namespaced form: `/coding-workflows:<skill-name>`.

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

## Hooks

The plugin ships lifecycle hooks that enforce workflow rules automatically. Hooks activate on plugin install -- no configuration needed.

### Shipped Hooks

| Hook | Event | Behavior | What It Enforces |
|------|-------|----------|------------------|
| `test-evidence-logger` | PostToolUse / PostToolUseFailure | Advisory (exit 0) | Logs test/lint evidence to session trail; warns on failure with Verification Gate reminder |
| `deferred-work-scanner` | PostToolUse | Advisory (exit 0) | Scans PR body at creation time for untracked deferral language without issue links |
| `stop-deferred-work-check` | Stop | Advisory (exit 0) | Warns when deferred work is detected in the transcript without follow-up issue references |
| `execute-issue-completion-gate` | Stop | Blocking (exit 2, escalates after threshold) | Prevents premature session exit when open PR has incomplete CI checks. With `review_gate: true`, also enforces review verdict polling. |
| `check-agent-output-completeness` | SubagentStop | Blocking (lenient) | Validates subagent output contains expected structured sections based on agent role |

### Disabling Hooks

Each hook can be disabled individually via environment variable:

```bash
# PostToolUse hooks
export CODING_WORKFLOWS_DISABLE_HOOK_TEST_EVIDENCE_LOGGER=1
export CODING_WORKFLOWS_DISABLE_HOOK_DEFERRED_WORK_SCANNER=1

# Stop hooks
export CODING_WORKFLOWS_DISABLE_HOOK_STOP_DEFERRED_WORK=1
export CODING_WORKFLOWS_DISABLE_HOOK_EXECUTE_ISSUE_COMPLETION_GATE=1

# SubagentStop hooks
export CODING_WORKFLOWS_DISABLE_HOOK_AGENT_OUTPUT_COMPLETENESS=1
```

The completion gate escalation threshold and review gate can be configured:

```bash
# Default is 3 -- after this many blocked stops, the hook degrades to advisory
export CODING_WORKFLOWS_ESCALATION_THRESHOLD=5
```

Or via `workflow.yaml`:

```yaml
# In .claude/workflow.yaml:
hooks:
  execute_issue_completion_gate:
    review_gate: true       # Enable review verdict polling (default: false)
    escalation_threshold: 5 # Override blocked-stop threshold (default: 3)
```

Environment variables take precedence over `workflow.yaml` values.

### Hook Merging

Plugin hooks merge with your user-level hooks (defined in `~/.claude/settings.json` or `.claude/settings.json`) and run in parallel. Plugin hooks do not replace or conflict with user hooks.

### Error Handling

- The **PostToolUse evidence logger** (`test-evidence-logger`) always exits 0. If it cannot parse input or match commands, it silently succeeds. On test failure, it injects advisory context but never blocks.
- The **PostToolUse deferral scanner** (`deferred-work-scanner`) always exits 0. If `gh` is unavailable or the PR cannot be fetched, it silently succeeds. Only fires on `gh pr create` commands.
- The **Stop advisory hook** (`stop-deferred-work-check`) always exits 0. If it cannot parse input or read the transcript, it silently succeeds.
- The **Stop completion gate** (`execute-issue-completion-gate`) fails open: if `gh` is unavailable, not authenticated, or returns errors, it warns and allows the stop. After the escalation threshold (default 3 blocked stops), it degrades to advisory mode. CI checking is always active; review verdict polling requires `review_gate: true` in workflow.yaml. This is an intentional departure from the advisory-only pattern -- the escalation counter prevents infinite loops while providing deterministic enforcement.
- The **SubagentStop hook** (`check-agent-output-completeness`) fails open: if it cannot read the transcript or patterns config, it allows the subagent to complete. Only blocks when all required sections are missing AND output is suspiciously short (< 200 chars).

## Configuration Reference

Configuration lives in `.claude/workflow.yaml`. Run `/coding-workflows:init-config` to generate it, or create it manually. See `templates/workflow.yaml` for the full schema with examples for Python, JavaScript, Rust, Go, and Ruby.

| Section | Purpose |
|---------|---------|
| `project` | Repo identity: org, name, language, git provider |
| `commands` | Test (focused + full), lint, typecheck, branch pattern |
| `planning` | Always-include agents, reference docs |
| `deliberation` | Conflict overrides for multi-round specialist dispatch |
| `hooks` | Hook behavior overrides (e.g., escalation threshold) |

## Agent Discovery

Workflow commands discover agents by scanning `.claude/agents/*.md` and reading their YAML frontmatter. Agents declare:

- `domains` -- keywords for matching (e.g., `[api, routes, async]`)
- `role` -- `specialist`, `reviewer`, or `architect`

Commands match agents to workflow phases: domain specialists during planning, reviewers during pre-PR review, TDD-focused agents during execution. See the `coding-workflows:agent-patterns` skill for the full metadata spec and examples.

## Skill Discovery

**Bundled skills** ship with the plugin. They encode general-purpose workflow knowledge and are updated via plugin updates. These are read-only.

**Project-specific skills** are generated by `/coding-workflows:generate-assets`. They encode your project's conventions, patterns, and domain knowledge. They live in `.claude/skills/` and are fully editable.

Skills can include supporting files (templates, examples, reference data) in a `resources/` subdirectory alongside `SKILL.md`.

Both bundled and project-specific skills auto-activate based on their `triggers` and `domains` frontmatter fields.

## Customization

Projects can override any plugin command by placing a same-named file in their own `.claude/commands/` directory. Claude Code's local-wins precedence means project commands shadow plugin commands automatically.

To customize a command:
1. Copy it from `plugins/coding-workflows/commands/` to `.claude/commands/`
2. Edit the local copy
3. The local version takes precedence

## Experimental Features

Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to enable agent team parallel execution.

When enabled:
- `/coding-workflows:execute-issue` can dispatch independent implementation layers to parallel agents via the `coding-workflows:agent-team-protocol` skill
- The `coding-workflows:deliberation-protocol` skill uses TeamCreate/SendMessage-based multi-round dispatch

When not set (default): all commands use Task-based sequential dispatch, which works for all users.

## CI Review Setup

The `review-pr` command works identically from CLI and CI. This section covers running it automatically via GitHub Actions using [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action). See the [FAQ](#faq) for how CI and CLI review relate.

CI review works at any [Getting Started](#getting-started) tier. At Tier 1, project settings are auto-detected. At Tier 2+, the workflow reads `.claude/workflow.yaml` from the repo checkout.

### Minimal Workflow

Create `.github/workflows/pr-review.yml`:

```yaml
name: PR Review

on:
  pull_request:
    types: [opened, synchronize, ready_for_review, reopened]
    # Optional: scope to specific paths (see Customization below)
    # paths:
    #   - 'src/**'
    #   - '!.github/workflows/**'

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
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 1  # Shallow clone is sufficient — review uses gh API, not local git history

      - name: Run PR Review
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          allowed_bots: 'claude[bot]'  # Prevents bot from re-triggering on its own comments
          track_progress: false         # Command manages its own iteration tracking
          use_sticky_comment: false     # Preserves review history across iterations
          claude_args: |
            --allowedTools "Read,Grep,Glob,Bash(gh issue create:*),Bash(gh issue view:*),Bash(gh label create:*),Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}

            You have the coding-workflows plugin installed.
            Run the /coding-workflows:review-pr command for PR ${{ github.event.pull_request.number }}.

            Use the REPO and PR NUMBER above for all operations.
```

> **Note:** This example assumes the `coding-workflows` plugin is installed in the repository. If the plugin is not installed, you can vendor the `review-pr` command by copying `commands/review-pr.md` to your repo and updating the prompt to reference the file path directly.

> **Resilience:** For production CI, consider inlining fallback review rules directly in the workflow prompt. See [Inline fallback for production CI](#inline-fallback-for-production-ci) below.

### Permissions, Secrets, and Inputs

#### GitHub Workflow Permissions

| Permission | Required | Purpose |
|------------|----------|---------|
| `contents: read` | Yes | Read repository files during checkout and review |
| `pull-requests: write` | Yes | Post review comments on the PR |
| `issues: write` | Yes | CREATE ISSUE protocol — files follow-up issues for non-blocking findings |
| `actions: read` | Yes | Required by `claude-code-action` internals |
| `id-token: write` | Yes | OIDC token exchange for `claude-code-action` authentication |

Without `issues: write`, reviews still run and post comments, but the CREATE ISSUE protocol fails silently — follow-up issues won't be created.

#### Repository Secrets

| Secret | Required | Purpose |
|--------|----------|---------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Yes | Authenticates `claude-code-action`. See the [setup guide](https://github.com/anthropics/claude-code-action) for how to obtain the token. |

#### Action Inputs

| Input | Required | Purpose |
|-------|----------|---------|
| `allowed_bots` | Yes | Set to `'claude[bot]'` to prevent the bot from re-triggering the workflow on its own review comments. Without this, the workflow can infinite-loop. Adjust if using a custom Claude integration with a different bot identity. |

### Allowed Tools

The `--allowedTools` flag restricts which tools Claude can use during CI review. This is a security boundary — general `Bash` access is intentionally excluded.

| Tool Pattern | Purpose |
|-------------|---------|
| `Read`, `Grep`, `Glob` | File analysis — read and search repository files |
| `Bash(gh pr view:*)` | Fetch PR metadata and count review iterations |
| `Bash(gh pr diff:*)` | Fetch PR diff for review |
| `Bash(gh pr comment:*)` | Post the review comment |
| `Bash(gh issue create:*)` | Create follow-up issues (CREATE ISSUE protocol) |
| `Bash(gh issue view:*)` | Fetch linked issue for compliance check |
| `Bash(gh label create:*)` | Ensure `review-followup` label exists |

The CI `--allowedTools` is more restrictive than the command's own `allowed-tools` declaration (which includes general `Bash` and `Task`). This is intentional: CLI usage has user oversight for each command, while CI runs unattended. In CI, general `Bash` access is scoped to specific `gh` subcommands for security, and `Task` (which enables sub-agents) is excluded entirely.

### Customization

**Path filters:** Add a `paths` block to scope which file changes trigger reviews. Use `!.github/workflows/**` to prevent the workflow from self-triggering.

Common patterns by ecosystem:

| Ecosystem | Suggested paths |
|-----------|----------------|
| TypeScript/JavaScript | `'src/**'`, `'**.ts'`, `'**.tsx'` |
| Python | `'**.py'`, `'pyproject.toml'` |
| Ruby/Rails | `'app/**'`, `'lib/**'`, `'**.rb'` |
| Go | `'**.go'`, `'go.mod'` |
| Documentation | `'**.md'`, `'**.yaml'`, `'**.yml'` |

**Sticky comments:** Set `use_sticky_comment: true` to update a single comment instead of posting new ones per iteration. Default `false` preserves review history.

**Iteration behavior:** The command tracks iterations via HTML comment markers (`<!-- content-review-iteration:N -->`). Iterations 1-3 run comprehensive reviews; iterations 4+ switch to verification mode (only check previous MUST FIX items). New commits trigger re-review automatically via the `synchronize` event.

**Project-specific review focus:** For more targeted reviews, generate a review config:

```
/coding-workflows:generate-assets review-config
```

This produces `.claude/review-config.yaml` with project-specific correctness criteria, integrity checks, compliance conventions, and anti-patterns. Commit this file — the `review-pr` command reads it automatically in both CLI and CI. Without it, reviews use the universal framework.

#### Inline fallback for production CI

For environments where plugin resolution may fail — production CI, airgapped networks, vendored command setups — inline critical review rules directly in the workflow prompt as a fallback. The command uses its own skill when available; inline rules ensure review coverage if resolution fails.

> **YAML formatting:** Use the literal block scalar (`|`) for multi-line prompt content. This preserves line breaks and avoids escaping issues. Indent the prompt body consistently (2 spaces).

Example workflow with inline fallback (extends the [minimal workflow](#minimal-workflow) above):

```yaml
      - name: Run PR Review
        uses: anthropics/claude-code-action@v1
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

            ---
            FALLBACK REVIEW RULES (apply if command or skill cannot be resolved;
            this is a static snapshot from the pr-review skill and may drift from
            skill updates -- use inline fallback only when resilience outweighs consistency):

            ## Severity Tiers
            Every finding must be classified into exactly one tier:
            - MUST FIX: Blocks merge. Incorrect behavior, broken references, security issues, missing acceptance criteria.
            - FIX NOW: Mandatory trivial fix. Small editorial fix that passes the Trivial Check below.
            - CREATE ISSUE: Non-trivial, tracked. Valid concern requiring separate work; does not block merge once filed.

            ## Trivial Check (FIX NOW vs CREATE ISSUE)
            FIX NOW when ALL true:
            - Single component change
            - No structural metadata changes
            - No new cross-component references
            - No behavioral semantic changes
            - Clearly editorial (typos, wording, formatting)

            CREATE ISSUE when ANY true:
            - Spans multiple components
            - Changes structural metadata
            - Changes behavioral logic or thresholds
            - Introduces new cross-component references

            ## Exit Criteria
            "Ready to merge" ONLY when ALL true:
            - Zero MUST FIX items remain
            - Zero FIX NOW items remain
            - All CREATE ISSUE items have been filed

            NEVER use qualified approval:
            - "Ready to merge once items are addressed" -- NO
            - "LGTM with minor changes" -- NO
            - "Approved pending X" -- NO

            ## CREATE ISSUE Protocol
            - ONE consolidated issue per review (not per finding)
            - Label: review-followup
            - Reference created issue number in review comment

            ## Iteration Mode
            - Iterations 1-3: COMPREHENSIVE (apply all review categories, raise every concern)
            - Iterations 4+: VERIFICATION (only verify previous MUST FIX items are fixed)
```

> **Note:** Inline rules are a static snapshot from the `pr-review` skill. If the skill's severity tiers, exit criteria, or trivial check rules are updated, the inline copy may drift. Use inline fallback only when resilience outweighs consistency.

**`ready_for_review` trigger:** The `ready_for_review` event type ensures PRs converted from draft to ready-for-review trigger a review. Remove it only if your team does not use draft PRs.

## FAQ

**What's the difference between `/coding-workflows:init-config`, `/coding-workflows:generate-assets`, and `/coding-workflows:setup`?**
`init-config` only creates `.claude/workflow.yaml`. `generate-assets` generates agents and/or skills from a codebase scan (requires config). `setup` is the full pipeline: CLAUDE.md check, config, and asset generation in one pass. Use `setup` for initial project onboarding; use `init-config` when you only need the config file; use `generate-assets` when you want to regenerate agents/skills without re-running the full pipeline.

**What's the difference between `/coding-workflows:prepare-issue` and `/coding-workflows:plan-issue`?**
`prepare-issue` runs the full pipeline: design session + plan + review. `plan-issue` skips the design session and goes straight to planning. Use `prepare-issue` for complex issues that need architectural discussion; use `plan-issue` for straightforward implementation work.

**What's the difference between CI review and CLI review?**
Both use the same `review-pr` command and `pr-review` skill. The command is CI/CLI agnostic — `gh` commands work in both environments. From CLI, run `/coding-workflows:review-pr <pr>` manually. For automated CI reviews on every pull request, see [CI Review Setup](#ci-review-setup).

**How do I set up project-specific review focus?**
Run `/coding-workflows:generate-assets review-config` to generate `.claude/review-config.yaml`. This scans your codebase and produces project-specific correctness criteria, integrity checks, compliance conventions, and anti-patterns. Without it, reviews use the universal framework from the `pr-review` skill.

**Which commands post to GitHub automatically?**
`/coding-workflows:plan-issue`, `/coding-workflows:review-plan`, `/coding-workflows:review-pr`, `/coding-workflows:design-session`, `/coding-workflows:create-issue`, and `/coding-workflows:prepare-issue` post comments or issues to GitHub without prompting. Review the output on the issue or PR after it's posted.

**How do project settings persist across commands?**
Settings are stored in `.claude/workflow.yaml`. Once created (via `init-config` or `setup`), all commands read from this file instead of auto-detecting. The file is committed to your repo and shared with your team.

**Is `/coding-workflows:setup` safe to run multiple times?**
Yes. It's idempotent. Existing files are preserved. Stale config is detected and offered for update. Manual files are never overwritten.

**Do I need agents configured?**
No. All commands work without agents. Agents enhance design sessions and reviews with project-specific expertise but are entirely optional.

**What is the requirements gate on `/coding-workflows:execute-issue`?**
The command stops and tells you to run `/coding-workflows:plan-issue` first if no plan is found. It also checks for a review comment before proceeding. This ensures plans are challenged before implementation.

**How do I customize a command?**
Copy it to `.claude/commands/` with the same filename. Your local version takes precedence over the plugin version.

**What happens if I run `/coding-workflows:execute-issue` without a plan?**
The command stops and tells you to run `/coding-workflows:plan-issue` first. It also checks for a review comment before proceeding.

**Can I skip the design session and go straight to planning?**
Yes. Use `/coding-workflows:plan-issue` directly instead of `/coding-workflows:prepare-issue`.

**How do I set up multi-round deliberation?**
Add conflict overrides to `.claude/workflow.yaml` under `deliberation.conflict_overrides`. When any specialist pair has a HIGH conflict override, multi-round dispatch activates automatically.

## Troubleshooting

**Issue is closed -- command fails**
Commands that post to GitHub issues check the issue state. If the issue is closed, the command will stop. Reopen the issue first.

**No plan found on issue**
`/coding-workflows:execute-issue` requires a plan comment (starting with `## Implementation Plan`) on the issue. Run `/coding-workflows:plan-issue <issue>` first.

**`gh` not found**
Install the GitHub CLI: `brew install gh` (macOS) or see [cli.github.com](https://cli.github.com). Then authenticate with `gh auth login`.

**Unexpected GitHub comments**
Commands post to GitHub automatically. If you're surprised by comments appearing on issues, check the [FAQ](#faq) about auto-posting behavior. All workflow commands that post to GitHub are documented above.

**Settings confirmation keeps appearing**
If you're repeatedly asked to confirm project settings, create a persistent config: `/coding-workflows:init-config`. Once `.claude/workflow.yaml` exists, auto-detection is skipped.

**CI review posts no comment**
Verify the `CLAUDE_CODE_OAUTH_TOKEN` secret is set in the repository settings. Check that `pull-requests: write` permission is configured in the workflow. See [CI Review Setup](#ci-review-setup).

**CI review runs but follow-up issues are not created**
The CREATE ISSUE protocol requires `issues: write` permission. Without it, reviews post normally but follow-up issue creation fails silently. Add `issues: write` to the workflow permissions block.

## License

MIT
