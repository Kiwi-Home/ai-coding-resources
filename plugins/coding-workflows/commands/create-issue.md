---
description: Create a well-structured issue on GitHub (best-effort: Linear, Jira, Asana)
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

Read the `coding-workflows:project-context` skill and follow its protocol for resolving project context (reads workflow.yaml, auto-detects project settings, validates configuration). **If the skill file does not exist, STOP:** "Required skill `coding-workflows:project-context` not found. Ensure the coding-workflows plugin is installed."

**Command-specific overrides:**
- **Conditional git_provider:** Check `git_provider` only when `{{platform}}` is `github` (stop with message if not `github`). For other platforms: skip `git_provider` check -- unlike sibling commands that always post to GitHub issues, this command targets the user's chosen tracker.

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Step 1: Read the Skill (MANDATORY)

Use the Read tool to read the `coding-workflows:issue-writer` skill bundled with this plugin. If the skill file doesn't exist, proceed without it and note the missing skill.

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

First, validate that `{{platform}}` is one of: `github`, `linear`, `jira`, `asana`. If not recognized, stop with a message listing supported platforms and their support levels (see table above).

Then create the issue using the appropriate method:

| Platform | Support | Method | Command/Tool |
|----------|---------|--------|--------------|
| github | Supported | CLI | `gh issue create --repo "{org}/{repo}"` |
| linear | Best-effort | CLI | `linear issue create` |
| jira | Best-effort | MCP | Use Jira MCP tool if available |
| asana | Best-effort | MCP | Use Asana MCP tool if available |

> Best-effort platforms depend on external tooling (CLI or MCP server) that the plugin does not install, configure, or test. Linear has a dedicated CLI (`linear`) with similar mechanics to `gh`; Jira and Asana require an MCP server to be configured. GitHub is the only platform with full config validation and tested error diagnostics.

## Step 5: Return URL

Return the issue URL when complete.

---

## Error Handling

**Target safety applies.** On any creation failure, the workflow stops and reports — it never substitutes a different target. See the `coding-workflows:issue-workflow` skill's Target Safety section.

| Error | Action |
|-------|--------|
| Config file missing + auto-detect fails | Ask user for org, repo, and platform-specific identifiers |
| `project.org` or `project.name` empty | Stop with message; ask user to provide values or create `workflow.yaml` |
| `git_provider` mismatch (GitHub platform) | Stop with message explaining the config says a different provider |
| CLI not installed (`gh`/`linear` not found) | Stop. Present the formatted issue body for manual creation. Suggest installing the CLI tool. |
| CLI failure (gh/linear) | Stop. Present: (1) the error message, (2) the target that was attempted and where it was resolved from (`workflow.yaml` or auto-detect), (3) the failed CLI command for retry, (4) the formatted issue body for manual creation. Best-effort diagnostic hint: repository not found → check `project.org`/`project.name` in `workflow.yaml`; authentication/permission error → check `gh auth status` and repo access; transient error (timeout, rate limit) → suggest retrying the same command. **Do NOT retry with a different target or without the `--repo` flag.** |
| MCP tool not available (Jira/Asana) | Stop. Present the formatted issue body; suggest creating in the web UI. |
| MCP tool call fails (Jira/Asana) | Stop. Present: (1) the MCP error message as-is, (2) the target that was attempted, (3) the formatted issue body for manual creation. Suggest checking MCP server configuration. **Do NOT attempt a different platform or target.** |
| Platform not recognized | Stop with message listing supported platforms and their support levels (see platform table) |
| Partial success (created but URL not captured) | Report success, suggest checking the target's issue list for the newly created issue. Do NOT re-create. |
