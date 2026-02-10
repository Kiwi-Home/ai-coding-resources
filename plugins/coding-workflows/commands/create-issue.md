---
description: Create a well-structured issue in your tracker
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
args:
  platform:
    description: "Issue tracker: github, linear, jira, asana"
    required: true
  description:
    description: "Text describing the issue (problem, feature, or task)"
    required: true
---

# Create Issue: {{platform}}

## Step 0: Resolve Project Context (MANDATORY)

1. **Read config:** Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract all fields. Proceed to step 3.
   - If file does not exist: proceed to step 2.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - Scan for project files: `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`
   - Infer test/lint commands from detected ecosystem
   - **CONFIRM with user:** "I detected [language] project [org/repo] with test command `[inferred]`. Is this correct?" DO NOT proceed without confirmation.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - If `{{platform}}` is `github`: `git_provider` must be `github` (stop with message if not). For other platforms: skip `git_provider` check — unlike sibling commands that always post to GitHub issues, this command targets the user's chosen tracker.

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Step 1: Read the Skill (MANDATORY)

Use the Read tool to read the `coding-workflows:issue-writer` skill (`skills/issue-writer/SKILL.md`) bundled with this plugin. If the skill file doesn't exist, proceed without it and note the missing skill.

Do not proceed until you have read it (or confirmed it's missing).

## Step 2: Transform Description

Use the `coding-workflows:issue-writer` skill to transform this into a well-structured issue:

{{description}}

Apply the skill's formatting patterns to produce a requirements-focused issue body with clear problem statement, acceptance criteria, and any relevant constraints.

## Step 3: Present for Confirmation

Show the formatted issue to the user, including:
- **Title**: The proposed issue title
- **Body**: The full formatted issue body

**DO NOT create the issue until the user approves.** Wait for explicit confirmation before proceeding to Step 4.

## Step 4: Create Issue on Platform

First, validate that `{{platform}}` is one of: `github`, `linear`, `jira`, `asana`. If not recognized, stop with a message listing supported platforms.

Then create the issue using the appropriate method:

| Platform | Method | Command/Tool |
|----------|--------|--------------|
| github | CLI | `gh issue create --repo "{org}/{repo}"` |
| linear | CLI | `linear issue create` |
| jira | MCP | Use Jira MCP tool if available |
| asana | MCP | Use Asana MCP tool if available |

## Step 5: Return URL

Return the issue URL when complete.

---

## Error Handling

| Error | Action |
|-------|--------|
| Config file missing + auto-detect fails | Ask user for org, repo, and platform-specific identifiers |
| `project.org` or `project.name` empty | Stop with message; ask user to provide values or create `workflow.yaml` |
| `git_provider` mismatch (GitHub platform) | Stop with message explaining the config says a different provider |
| CLI failure (gh/linear) | Present the formatted issue body for manual creation; include the failed command |
| MCP tool not available (Jira/Asana) | Present the formatted issue body; suggest creating in the web UI |
| MCP tool call fails | Present the formatted issue body with error details |
| Platform not recognized | Stop with message listing supported platforms: github, linear, jira, asana |
