---
description: Merge a PR and clean up branch + worktree for a completed issue
args:
  issue:
    description: "Issue number (e.g., 10) or full reference (e.g., other-repo#10)"
    required: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Merge Issue: {{issue}}

Merge an approved PR and clean up the local branch and worktree in one step. This is the natural successor to `/coding-workflows:execute-issue` -- that command stops at PR creation, this command closes the loop after human approval.

**When to use:**
- After a PR created by `/coding-workflows:execute-issue` or `/coding-workflows:execute-issue-worktree` is approved
- After manually confirming a PR is ready to merge

**When NOT to use:**
- To clean up abandoned work (use `/coding-workflows:cleanup-worktree` instead)
- Before human approval -- this command merges the PR

**NEVER auto-triggers.** This is a deliberate user action after human merge approval.

---

## Step 0: Resolve Project Context (MANDATORY)

1. **Read config:** Use the Read tool to read `.claude/workflow.yaml`.
   - If file exists: extract all fields. Also read `project.remote` (default: `origin` if field is absent or empty). Use this as the identity remote name for any `git remote get-url` or `gh --repo` resolution. Proceed to step 3.
   - If file does not exist: proceed to step 2.

2. **Auto-detect (zero-config fallback):**
   - Run `git remote get-url origin` to extract org and repo name
   - **CONFIRM with user:** "I detected [org/repo]. Is this correct?" DO NOT proceed without confirmation.
   - Note: merge only needs org/repo and merge strategy. Test/lint commands and ecosystem detection are not needed.

3. **Validate resolved context:**
   - `project.org` and `project.name` must be non-empty (stop if missing)
   - `git_provider` must be `github` (stop with message if not)
   - If `project.remote` is set to a non-empty value but `git remote get-url {remote}` fails: stop with error: "Configured remote '{remote}' not found. Run `git remote -v` to see available remotes, or update project.remote in .claude/workflow.yaml." Do NOT silently fall back to origin.

**DO NOT GUESS configuration values.**

---

## Step 1: Find PR for Issue

Parse `{{issue}}`:
- Plain number (e.g., `10`) -> use the default repo from resolved config
- With repo (e.g., `other-repo#10`) -> use as-is with the org from resolved config

Search for the PR associated with this issue:

```bash
gh pr list --repo {org}/{repo} --search "{issue_num}" --state all --json number,title,state,headRefName --jq '.[] | select(.headRefName | test("(^|/)'"${issue_num}"'[-/]|[-/]'"${issue_num}"'$"))'
```

**If no PR found:** Stop with message: "No PR found for issue #{issue_num}. Check that a PR exists with a branch containing the issue number."

**If multiple PRs found:** List them with number, title, state, and branch name. Ask the user which one to merge.

**If PR is already merged:** Skip to Step 4 (Local Cleanup) -- the merge already happened, just clean up locally.

**If PR is closed (not merged):** Stop with message: "PR #{num} is closed but not merged. If you want to clean up the branch and worktree, use `/coding-workflows:cleanup-worktree {{issue}}`."

---

## Step 2: Verify PR Status

```bash
gh pr view {PR_NUM} --repo {org}/{repo} --json state,reviewDecision,statusCheckRollup
```

Check each condition:

| Condition | Action |
|-----------|--------|
| Checks failing | Warn: "CI checks are failing on PR #{num}." Ask user to confirm or abort. |
| Not approved (`reviewDecision` != `APPROVED`) | Warn: "PR #{num} has not been approved." Ask user to confirm or abort. |
| Both passing and approved | Proceed without prompting. |

**If user aborts at any warning:** Stop with message: "Merge aborted. Fix the issues and re-run `/coding-workflows:merge-issue {{issue}}`."

---

## Step 3: Merge

Determine merge strategy:
1. Read `commands.merge_strategy` from `.claude/workflow.yaml` (if configured)
2. **Validate:** If a value is configured and is not one of `squash`, `rebase`, or `merge`, warn the user:
   > "Invalid merge_strategy '[value]' in workflow.yaml. Valid values: squash, rebase, merge. Falling back to squash."
   Then use `squash` as the strategy. (If the value is empty, null, or absent, treat as not configured -- no warning.)
3. Default (if not configured): `squash`

```bash
gh pr merge {PR_NUM} --repo {org}/{repo} --{strategy} --delete-branch
```

**`--delete-branch`** deletes the remote branch after merge.

**If merge fails:** Report the error and stop. Do not proceed to cleanup -- the user needs to resolve the merge failure first.

---

## Step 4: Local Cleanup

### 4a. Update default branch

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
# Identity remote: uses project.remote to determine default branch name
REMOTE="{resolved_remote}"  # project.remote from config, default: origin
DEFAULT_BRANCH=$(git symbolic-ref "refs/remotes/${REMOTE}/HEAD" | sed "s@^refs/remotes/${REMOTE}/@@")
# Operational remote (fetch/pull below): uses origin (push target)
git checkout "$DEFAULT_BRANCH"
git pull origin "$DEFAULT_BRANCH"
```

### 4b. Remove worktree (if exists)

Worktrees must be removed **before** deleting the local branch, because `git branch -d/-D` fails if the branch is checked out in a worktree.

```bash
git worktree list
```

Match by issue number in the worktree path (e.g., `../{repo}-{issue_num}`) or branch name.

If a matching worktree is found:

**Safety check:** Check for uncommitted changes:
```bash
git -C {WORKTREE_PATH} status --porcelain
```
If non-empty: Warn with file list. Ask user to confirm removal (changes will be lost since the PR is already merged).

```bash
git worktree remove {WORKTREE_PATH}
```

**If worktree is locked:** Attempt `git worktree unlock {path}` then retry.

**If no worktree found:** Skip gracefully.

### 4c. Delete local feature branch

Derive the branch name by matching the issue number:

```bash
git branch --list "feature/{issue_num}-*" "feature/{issue_num}" "{issue_num}-*"
```

If a matching branch is found:
```bash
git branch -d {BRANCH}
```

**If `-d` fails (branch not fully merged):** The remote was already deleted by `--delete-branch`. Use `-D` since the merge is confirmed.

**If no matching branch found:** Skip gracefully -- branch may have already been deleted.

### 4d. Prune

```bash
git worktree prune
```

---

## Step 5: Report

```
PR #{num} merged ({strategy}) into {default_branch}
Remote branch: deleted (via --delete-branch)
Local branch: {deleted | not found (already cleaned)}
Worktree: {removed at {path} | no worktree found}

Merged PR: {PR_URL}
```

---

## Error Handling

| Error | Action |
|-------|--------|
| No PR found for issue | Stop with message, suggest checking branch naming |
| Multiple PRs match | List matches, ask user to specify |
| PR already merged | Skip to Step 4 (local cleanup only) |
| PR closed (not merged) | Stop, suggest `/coding-workflows:cleanup-worktree` |
| CI checks failing | Warn, ask for confirmation to proceed |
| PR not approved | Warn, ask for confirmation to proceed |
| Merge fails (conflicts, branch protection) | Stop, report error, do not cleanup |
| `git branch -d` fails | Use `-D` (merge is confirmed, safe to force-delete) |
| Worktree has uncommitted changes | Warn with file list, ask for confirmation |
| Worktree is locked | Attempt unlock, retry removal |
| No worktree found | Skip gracefully (not an error) |
| No local branch found | Skip gracefully (not an error) |

---

## Cross-References

- `/coding-workflows:execute-issue` -- creates the PR that this command merges
- `/coding-workflows:execute-issue-worktree` -- creates PR + worktree that this command merges and cleans up
- `/coding-workflows:cleanup-worktree` -- standalone worktree removal for abandoned work or manual merges
- `coding-workflows:issue-workflow` -- the skill defining the full issue lifecycle
