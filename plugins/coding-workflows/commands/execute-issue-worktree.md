---
description: Execute a planned+reviewed issue in an isolated git worktree. Creates worktree, implements changes, commits, pushes, and creates PR. Use AFTER planning is complete.
args:
  issue:
    description: "Issue number (e.g., 10) or full reference (e.g., other-repo#10)"
    required: true
allowed-tools:
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Bash
  - Task
  - TeamCreate
  - TeamDelete
  - TaskCreate
  - TaskUpdate
  - TaskList
  - SendMessage
---

# Execute Issue in Worktree: {{issue}}

Execute an issue in an isolated git worktree. This wraps the standard `/coding-workflows:execute-issue` workflow with worktree setup and teardown guidance.

**When to use this instead of `/coding-workflows:execute-issue`:**
- Working on multiple issues in parallel (each gets its own worktree)
- Running parallel Claude Code sessions on the same repo
- Keeping the main checkout clean while experimenting

---

## Step 0: Resolve Project Context (MANDATORY)

1. **Read config:** Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract all fields. Also read `project.remote` (default: `origin` if field is absent or empty). Use this as the identity remote name for any `git remote get-url` or `gh --repo` resolution. Proceed to step 3.
   - If file does not exist: proceed to step 2.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - Scan for project files: `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Gemfile`
   - Infer test/lint commands from detected ecosystem
   - **CONFIRM with user:** "I detected [language] project [org/repo] with test command `[inferred]`. Is this correct?" DO NOT proceed without confirmation.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - `commands.test.full` should exist (warn if missing, skip test steps)
   - `git_provider` must be `github` (stop with message if not)
   - If `project.remote` is set to a non-empty value but `git remote get-url {remote}` fails: stop with error: "Configured remote '{remote}' not found. Run `git remote -v` to see available remotes, or update project.remote in .claude/workflow.yaml." Do NOT silently fall back to origin.

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Step 1: Pre-flight Validation

Parse `{{issue}}`:
- Plain number (e.g., `10`) -> use the default repo from resolved config
- With repo (e.g., `other-repo#10`) -> use as-is with the org from resolved config

```bash
gh issue view [NUMBER] --repo "{org}/{repo}" --json title,body,state
```

**Stop if:**
- Issue not found
- Issue is closed
- No `## Implementation Plan` in comments (suggest `/coding-workflows:plan-issue {{issue}}`)
- No `## Plan Review` or `## Plan Confirmed` in comments (suggest `/coding-workflows:review-plan {{issue}}`)

---

## Step 2: Create Worktree

### 2a. Ensure on default branch

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"
git fetch origin
# Identity remote: uses project.remote to determine default branch name
REMOTE="{resolved_remote}"  # project.remote from config, default: origin
DEFAULT_BRANCH=$(git symbolic-ref "refs/remotes/${REMOTE}/HEAD" | sed "s@^refs/remotes/${REMOTE}/@@")
git checkout "$DEFAULT_BRANCH"
# Operational remote (pull): uses origin (push target)
git pull origin "$DEFAULT_BRANCH"
```

### 2b. Compute paths

Derive a description slug from the issue title (same algorithm used by `execute-issue` for branch naming):
1. Convert to lowercase
2. Replace any character that is not `[a-z0-9]` with a hyphen
3. Collapse consecutive hyphens into one
4. Trim leading and trailing hyphens
5. Truncate to 30 characters
6. Trim any trailing hyphen created by truncation

Compute the branch name using `commands.branch_pattern` from config (default: `feature/{issue_num}-{description}`).

Compute the worktree path as a sibling directory: `../{repo}-{issue_num}` (where `{repo}` is `project.name` from config).

### 2c. Check for conflicts

- If a worktree for this issue already exists (`git worktree list`): use **AskUserQuestion** with "Resume in existing worktree" and "Remove and recreate" as options
- If a local branch with the same name exists: use **AskUserQuestion** with "Reuse existing branch" and "Force-create with -B" as options
- If the main repo has uncommitted changes: stop and report

### 2d. Create

```bash
BRANCH="feature/{issue_num}-{slug}"
WORKTREE_PATH="$REPO_ROOT/../{repo}-{issue_num}"

git worktree add "$WORKTREE_PATH" -b "$BRANCH"
```

Verify creation succeeded. Report the worktree path.

**On failure:** Stop and report the git error message. Do not attempt recovery.

---

## Step 3: Execute in Worktree

**CRITICAL working directory rule:** ALL bash commands for the remainder of this session MUST use absolute paths rooted at the worktree path, or be prefixed with `cd {WORKTREE_ABSOLUTE_PATH} &&`. The session's default working directory has NOT changed -- only your bash commands target the worktree.

**Branch status:** The feature branch was already created by `git worktree add` in Step 2. You are already on this branch in the worktree.

Now follow the `/coding-workflows:execute-issue {{issue}}` workflow with these modifications:
- **Step 0 (Resolve Project Context):** Run as normal -- the worktree shares the repo's committed `.claude/` directory, so config resolution works transparently. Read `.claude/workflow.yaml` using the worktree absolute path (e.g., `{WORKTREE_ABSOLUTE_PATH}/.claude/workflow.yaml`).
- **Step 1 (Read the Skill):** Run as normal
- **Step 2 (Load the Plan):** Run as normal -- `gh` is directory-independent
- **Feature branch creation:** SKIP -- the branch already exists from `git worktree add` in Step 2 above. Do not run `git checkout -b`.
- **All other steps:** Run as normal -- TDD loop, verification gate, spec compliance, PR creation, CI+review loop

**CWD delegation contract:** When following `execute-issue` instructions, the absolute path / `cd` prefix rule from above continues to apply. Every bash command that `execute-issue` would run in the repo root MUST be adapted to target the worktree path instead. Git commands that use `REPO_ROOT` should substitute `{WORKTREE_ABSOLUTE_PATH}`. The `execute-issue` workflow does not know about worktrees -- this command is responsible for translating all path references.

---

## Step 4: Report Completion

Output:
- PR URL
- Worktree location (for review)
- Suggest: "When ready to merge, run `/coding-workflows:merge-issue {{issue}}` to merge PR, delete branch, and remove worktree."

---

## Error Handling

| Error | Action |
|-------|--------|
| Issue not found | Stop before worktree creation |
| No plan/review found | Stop, suggest plan-issue or review-plan |
| Worktree already exists for this issue | AskUserQuestion: "Resume in existing" vs "Remove and recreate" |
| Local branch already exists | AskUserQuestion: "Reuse existing branch" vs "Force-create with -B" |
| Worktree creation fails (path conflict, permissions) | Stop, report git error message |
| Uncommitted changes in main repo | Stop: "Main repo has uncommitted changes. Commit or stash first." |
| Execution fails mid-way (no PR) | Preserve worktree. Report: "Execution incomplete. Worktree preserved at {WORKTREE_PATH}." |
| Execution fails after PR creation | Report partial state: "PR #X created. Worktree at {WORKTREE_PATH}." |

**Worktree is always preserved on failure** -- never auto-clean. User runs `/coding-workflows:cleanup-worktree` manually when done inspecting.

---

## Cross-References

- `/coding-workflows:execute-issue` -- the core execution workflow this command wraps
- `/coding-workflows:merge-issue` -- merges PR and cleans up after execution completes and PR is approved
- `/coding-workflows:cleanup-worktree` -- post-merge worktree removal
- `coding-workflows:issue-workflow` -- the skill defining execution phases, verification gates, and CI+review loop

## Notes

- Worktree remains after PR creation (you review before merge)
- If execution fails, worktree is left in place for debugging
- The worktree shares the repo's git history, committed config, and agent definitions
- If `.claude/workflow.yaml` or `.claude/agents/` are not committed, the worktree will not have them -- commit first
