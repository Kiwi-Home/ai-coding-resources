# Changelog

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
