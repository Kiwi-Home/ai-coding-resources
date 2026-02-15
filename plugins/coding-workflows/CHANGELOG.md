# Changelog

## 1.1.1 — 2026-02-15

### New commands

- **check-updates** — Check upstream dependencies for new releases and changelog updates.
- **cleanup-worktree** — Remove worktree and branch for a completed issue with unmerged-changes safety check.
- **execute-issue-worktree** — Execute a planned+reviewed issue in an isolated git worktree.
- **merge-issue** — Merge a PR and clean up branch + worktree for a completed issue.

### New hook

- **check-dependency-version** — PreToolUse hook that warns when dependency-add commands lack version pins.

### New skills

- **complexity-triage** — Complexity assessment framework for routing issues to appropriate preparation depth.
- **knowledge-freshness** — Staleness triage framework for evaluating when training data is reliable vs. when verification is required.
- **skill-creator** — Guides creation of effective skills with specialized knowledge, workflows, or tool integrations. Includes init/validate/package scripts and reference material.

### Skill reference material

New bundled references across skills for deeper content:

- agent-patterns, asset-discovery, codebase-analysis, issue-workflow (4 refs), issue-writer (moved resources/ → references/), pr-review, systematic-debugging (2 refs), tdd-patterns

Supporting files: `templates/upstream-sources.yaml` (registry for check-updates).

### Command improvements

All existing commands updated with cross-cutting improvements:

- Multi-remote support and configurable remote preference for git URL formats
- Setup improvements: /init recommendation flow, multi-layer asset generation
- Create-issue: Target Safety principle and hardened error handling
- PR review: disposition pre-filter, collect-then-file gate, cross-iteration dedup, concurrent CI fix
- Design-session: reduced token consumption by scoping agent context

### Skill refinements

- Frontmatter standardized: invocation controls, description format
- Cross-references now use namespace format, not file paths
- Deliberation protocol: clarified engagement criteria and observability scope

### Hook and configuration updates

- Hook naming convention standardized across documentation
- Updated `_workflow-config.sh` shared utilities and `hooks.json` registrations

## 1.1.0 — 2026-02-11

### Lifecycle hooks

New hook system that enforces workflow quality during execution. Hooks fire on
PostToolUse, Stop, and SubagentStop events.

- **test-evidence-logger** — Logs test/lint results to a session evidence trail; warns when fresh passing evidence is required before completion.
- **deferred-work-scanner** — Scans PR bodies for untracked deferral language and injects advisory context referencing follow-up issue thresholds.
- **stop-deferred-work-check** — Advisory warning when deferred-work language appears in transcript without linked issue references.
- **execute-issue-completion-gate** — Blocks session exit until CI passes and optional review verdict is found, with configurable escalation thresholds.
- **check-agent-output-completeness** — Validates subagent output contains expected structured sections (assessment, verdict, confidence) based on agent role.

Supporting files: `hooks.json` (hook registration), `_workflow-config.sh` (shared utilities for JSON parsing, test detection, hook disabling), `_completion-patterns.json` (required output sections by agent role), `validate-plugin-docs.sh` (build-time documentation consistency checker).

### New skills

- **systematic-debugging** — Structured methodology for hypothesis-driven failure resolution with evidence collection gates, failure classification, and fix validation criteria.
- **tdd-patterns** — Stack-aware TDD patterns and anti-patterns covering test selection, isolation, assertion quality, and language-specific testing idioms.

### Documentation alignment

All commands and skills updated to use YAML frontmatter as the single source of
truth for descriptions and tool declarations. README and help.md now
auto-validate against frontmatter via the `validate-plugin-docs` hook.

- All 11 commands: frontmatter standardization, tools field consolidation
- README.md, help.md: updated to reflect hooks, new skills, and consistent descriptions
- skills/agent-patterns, agent-team-protocol, asset-discovery, issue-workflow, issue-writer, pr-review, stack-detection: frontmatter alignment and content refinements

### Configuration

- **templates/workflow.yaml** — Review gate is now opt-in (`review_gate: true`) rather than always-on

## 1.0.0 — Initial Public Release

Full engineering workflow plugin for planning, reviewing, and executing GitHub issues with specialist agents.
