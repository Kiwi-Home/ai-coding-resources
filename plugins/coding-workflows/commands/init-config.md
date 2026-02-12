---
description: Bootstrap workflow.yaml by auto-detecting project settings
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

# Init Config

Bootstrap `.claude/workflow.yaml` for this project by auto-detecting settings and confirming with the user.

---

## Step 1: Check for Existing Config

Use the Read tool to read `.claude/workflow.yaml`.

- **If file exists:** Show the current config. Run review automation detection from Step 2e. If the detection result differs from the current `review_gate` value, include it in a drift report (e.g., "Review automation detected in CI workflows but `review_gate` is currently `false`. Update?"). Ask: "Configuration already exists. Do you want to update it?" If no, stop.
- **If file does not exist:** Continue to Step 2.

---

## Step 2: Auto-Detect Project Settings

### 2a. Repository Info

```bash
git remote get-url origin
```

Extract `org` and `repo` from the remote URL. Supported formats:
- `git@github.com:ORG/REPO.git`
- `https://github.com/ORG/REPO.git`
- `https://github.com/ORG/REPO`

If the remote is not GitHub (e.g., gitlab.com, bitbucket.org):
> "This plugin currently requires GitHub. GitLab and Bitbucket support is planned for a future version. You can still create the config, but workflow commands that use `gh` CLI will not work."

### 2b. Language Detection

Use the language detection table from the `coding-workflows:stack-detection` skill (`plugins/coding-workflows/skills/stack-detection/SKILL.md`).

If multiple detected, ask the user which is primary.

### 2c. Infer Commands

Based on detected language, infer test/lint/typecheck commands:

| Language | Test | Lint | Typecheck |
|----------|------|------|-----------|
| Python (uv) | `uv run pytest` | `uv run ruff check --fix .` | `uv run mypy .` |
| Python (pip) | `pytest` | `ruff check --fix .` | `mypy .` |
| JavaScript/TypeScript | `npm test` | `npm run lint` | `npx tsc --noEmit` |
| Rust | `cargo test` | `cargo clippy --fix` | _(built-in)_ |
| Go | `go test ./...` | `golangci-lint run` | _(built-in)_ |
| Ruby | `bundle exec rake test` | `bundle exec rubocop -a` | _(N/A)_ |

These are starting suggestions. The user will confirm or override in Step 3.

### 2d. Monorepo Detection

Check for monorepo indicators:
- Multiple language files at root (e.g., `pyproject.toml` + `package.json` in distinct subdirectories)
- Workspace files (`pnpm-workspace.yaml`, Cargo workspace in `Cargo.toml`, Go workspace `go.work`)

If monorepo detected:
> "This appears to be a monorepo. Monorepo support is planned for v2. For now, configure for your primary service directory."

### 2e. Review Automation Detection

Scan `.github/workflows/*.yml` and `.github/workflows/*.yaml` for automated PR review signals:

**Detection patterns** (in workflow file contents):
- `review-pr` or `review_pr` (plugin's own review command)
- `claude` appearing near `review` (within 5 lines)
- Common review bot references: `reviewbot`, `pr-review`, `code-review`

**Detection patterns** (in workflow triggers):
- Workflow triggered on `pull_request` events containing review-related steps

If any match found, set `detected_review_automation: true`.
This is a suggestion signal, not a hard detection -- user confirms in Step 3.

---

## Step 3: Confirm with User

Present detected settings and ask for confirmation (max 3 questions):

**Question 1** (always): Show all detected values and ask:
> "I detected a **[language]** project at **[org]/[repo]**. Test command: `[inferred]`. Lint: `[inferred]`. Is this correct, or would you like to change anything?"

**Question 2** (if test command wasn't detected): Ask for test commands.

**Question 3** (if branch pattern preference): Show default `feature/{issue_num}-{description}` and ask if they want a different pattern.

**Question 4** (if review automation detected in Step 2e):
> "I detected automated PR review in your CI workflows. I'll enable the review gate so the completion hook waits for review verdicts before allowing session exit. OK?"

If review automation was not detected, default to `review_gate: false` without asking.

**DO NOT proceed without user confirmation.** If a value cannot be detected, ask the user directly.

---

## Step 4: Write Config File

Write `.claude/workflow.yaml` with confirmed values:

```yaml
version: 1

project:
  name: REPO_NAME
  org: ORG_NAME
  language: LANGUAGE
  git_provider: github

commands:
  test:
    focused: "TEST_FOCUSED_CMD {path}"
    full: "TEST_FULL_CMD"
  lint: "LINT_CMD"
  typecheck: "TYPECHECK_CMD"  # omit if not applicable
  branch_pattern: "feature/{issue_num}-{description}"

planning:
  always_include: []
  reference_docs:
    - CLAUDE.md

deliberation:
  conflict_overrides: []

hooks:
  execute_issue_completion_gate:
    review_gate: REVIEW_GATE_VALUE  # true if review automation detected + confirmed
```

Omit optional fields that don't apply (e.g., `typecheck` for Ruby). Set `review_gate` to `true` only if review automation was detected in Step 2e and confirmed by the user; otherwise set to `false`.

---

## Step 5: Next Steps

After writing the config:

```
Configuration saved to .claude/workflow.yaml

Next steps:
- Commit the file: git add .claude/workflow.yaml
- Generate project-specific agents and skills: /coding-workflows:generate-assets
  (Or use /coding-workflows:setup for full project initialization)
- Start planning: /coding-workflows:plan-issue <issue-number>
```
