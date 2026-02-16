---
name: project-context
description: |
  Shared context-resolution pattern for workflow commands. Encodes the canonical
  3-step protocol (read config, auto-detect, validate) with extension points
  for command-specific behavior. Use when: resolving project context, reading
  workflow config, or auto-detecting project settings.
domains: [project, context, configuration, workflow]
user-invocable: false
---

# Project Context Resolution Protocol

Canonical 3-step protocol for resolving project context in workflow commands. Commands reference this skill instead of duplicating the pattern inline.

## Core Protocol

### Step 1: Read Config

Use the Read tool to read `.claude/workflow.yaml`.

- If file exists: extract all fields. Read `project.remote` (default: `origin` if field is absent or empty). Use this as the identity remote name for any `git remote get-url` or `gh --repo` resolution. Proceed to Step 3 (Validate).
- If file does not exist: proceed to Step 2 (Auto-Detect).

### Step 2: Auto-Detect (Zero-Config Fallback)

Behavior varies by mode. Commands specify which mode to use; **Full** is the default.

| Mode | Project File Scan | Test/Lint Inference | Ecosystem Detection | Confirmation Prompt |
|------|-------------------|--------------------|--------------------|-------------------|
| **Full** (default) | Yes | Yes | No | "I detected [language] project [org/repo] with test command `[inferred]`. Is this correct?" |
| **Lightweight** | Yes | No | No | "I detected [language] project [org/repo]. Is this correct?" |
| **Minimal** | No | No | No | "I detected [org/repo]. Is this correct?" |
| **Ecosystem** | Yes | No | Yes (read `coding-workflows:stack-detection` skill) | "I detected [language] project [org/repo] with ecosystem `[detected]`. Is this correct?" |

**Common across all modes:**
- Run `git remote get-url origin` to extract org and repo name
- **CONFIRM with user** using the mode-specific prompt. DO NOT proceed without confirmation.

**When project file scan is enabled**, scan for: `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`.

**When ecosystem detection is enabled**, read the `coding-workflows:stack-detection` skill and use its tables for language + framework detection. Store the resolved ecosystem identifier for use in later steps (the consuming command specifies where).

### Step 3: Validate

- `project.org` and `project.name` must be non-empty (stop if missing)
- `git_provider` must be `github` (stop with message if not) -- unless the command specifies a conditional override
- If `project.remote` is set to a non-empty value but `git remote get-url {remote}` fails: stop with error: "Configured remote '{remote}' not found. Run `git remote -v` to see available remotes, or update project.remote in .claude/workflow.yaml." Do NOT silently fall back to origin.

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Validation Extensions

Commands may add validation checks beyond the core protocol.

| Extension | Behavior | Override Pattern |
|-----------|----------|-----------------|
| Test Command Check | Additionally validate `commands.test.full` exists (warn if missing, skip test steps) | Command adds to override block |
| Conditional git_provider | Replace default `git_provider` validation with command-specific conditional logic | Command replaces validation inline |

---

## Target Safety

Once a target is resolved in Step 0 (whether from config or auto-detect), it is **locked**:

- Never re-resolve after a CLI failure
- Never silently substitute with a different remote or target
- Present diagnostic information on failure, then STOP

Cross-reference: `coding-workflows:issue-workflow` Target Safety (lines 42-50) for the full principle and rationale (#224).

---

## Anti-Patterns

- **Silent remote fallback after failure** (#224) -- never substitute a different remote or target after a CLI command fails
- **Guessing configuration values** -- if a value cannot be read or confirmed, ask the user
- **Skipping user confirmation in auto-detect path** -- always confirm, regardless of mode
- **Re-resolving target after CLI command failure** -- the resolved target is locked for the session
- **Adding ecosystem/test detection to Minimal-mode commands** -- defeats the purpose of reduced scope

---

## Cross-References

- `coding-workflows:stack-detection` -- used by Ecosystem auto-detect mode
- `coding-workflows:issue-workflow` -- Target Safety principle, execution-phase Step 0

**Consuming commands:**
- `plan-issue` (Full, no overrides)
- `execute-issue` (Full + Test Command Check)
- `execute-issue-worktree` (Full + Test Command Check)
- `design-session` (Lightweight)
- `prepare-issue` (Lightweight)
- `review-plan` (Lightweight)
- `merge-issue` (Minimal)
- `cleanup-worktree` (Minimal)
- `create-issue` (Full + Conditional git_provider)
- `review-pr` (Ecosystem)
