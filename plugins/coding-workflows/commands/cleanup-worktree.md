---
description: Remove worktree and branch for a completed issue; idempotent with unmerged-changes safety check
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

# Cleanup Worktree: {{issue}}

Remove the worktree and branch for a completed issue. Safe and idempotent -- warns before destructive actions, handles already-cleaned state gracefully.

**When to use:**
- After merging a PR created via `/coding-workflows:execute-issue-worktree {{issue}}`
- Cleaning up abandoned work (PR won't be merged)
- Cleaning up after a manual merge via the GitHub UI

---

## Step 0: Resolve Project Context (MANDATORY)

Read the `coding-workflows:project-context` skill and follow its protocol for resolving project context (reads workflow.yaml, auto-detects project settings, validates configuration). **If the skill file does not exist, STOP:** "Required skill `coding-workflows:project-context` not found. Ensure the coding-workflows plugin is installed."

**Command-specific overrides:**
- Use **Minimal** auto-detect mode (cleanup only needs org/repo for PR status checks)

**DO NOT GUESS configuration values.** If a value cannot be read from workflow.yaml or confirmed via auto-detection, ask the user.

---

## Step 1: Locate Worktree

Parse `{{issue}}` to extract the issue number.

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
git worktree list
```

Match by:
1. Issue number in the worktree path (e.g., `../{repo}-{issue_num}`)
2. Issue number in the branch name (e.g., `feature/{issue_num}-*`)

**If no match:** Warn "No worktree found for issue {num}" and exit cleanly (idempotent -- not an error).

**If multiple matches:** List them with paths and branch names, then use **AskUserQuestion** with each worktree as an option (label: path, description: branch name). Use the selected worktree for subsequent steps.

---

## Step 2: Safety Checks

For each check, warn the user and require explicit confirmation via **AskUserQuestion** before proceeding. Present "Proceed" and "Abort" as options, with the warning details in the description.

### Uncommitted changes
```bash
git -C {WORKTREE_PATH} status --porcelain
```
If output is non-empty: warn with the file list.

### Unpushed commits
```bash
git -C {WORKTREE_PATH} log @{u}.. --oneline 2>/dev/null
```
If output is non-empty: warn with the commit list. (Handle case where no upstream is set.)

### Open PR on branch
```bash
gh pr list --head {BRANCH} --repo {org}/{repo}
```
If a PR is open: warn "PR #N is still open. Deleting the branch will close the PR."

**If any warnings were shown:** Use **AskUserQuestion** with "Proceed with cleanup" and "Abort" as options, listing all warnings in the description. Do not proceed to removal without explicit user selection.

---

## Step 3: Remove

Run these steps in order:

```bash
# 1. Remove worktree
git worktree remove {WORKTREE_PATH}

# 2. Delete local branch (-d for merged, user confirms -D for unmerged)
git branch -d {BRANCH}

# 3. Prune stale worktree references
git worktree prune
```

**If worktree is locked:** Attempt `git worktree unlock {path}` then retry removal.

**If `git worktree remove` fails (dirty):** Use **AskUserQuestion** with "Force remove (--force)" and "Abort" as options, noting that uncommitted changes will be lost.

**If `git branch -d` fails (unmerged):** Use **AskUserQuestion** with "Force delete (-D)" and "Keep branch" as options, warning that the branch has unmerged commits.

**If branch not found (already deleted):** Skip gracefully and continue to prune.

---

## Step 4: Report

List what was removed:
- Worktree path
- Branch name
- Prune result

---

## Error Handling

| Error | Action |
|-------|--------|
| No worktree found for issue | Warn and exit cleanly (idempotent) |
| Multiple worktrees match | List matches, use AskUserQuestion to disambiguate |
| Uncommitted changes in worktree | Warn with file list, AskUserQuestion to confirm |
| Unpushed commits on branch | Warn with commit list, AskUserQuestion to confirm |
| Open PR on branch | Warn about PR closure, AskUserQuestion to confirm |
| Worktree is locked | Attempt unlock, retry removal |
| `git worktree remove` fails (dirty) | AskUserQuestion: "Force remove (--force)" vs "Abort" |
| `git branch -d` fails (unmerged) | AskUserQuestion: "Force delete (-D)" vs "Keep branch" |
| Branch already deleted | Skip gracefully, continue to prune |
| Worktree was manually rm'd but still in git list | `git worktree prune` handles this |

---

## Cross-References

- `/coding-workflows:merge-issue` -- merges PR and cleans up in one step (preferred for normal workflow; use `cleanup-worktree` for abandoned work or manual merges)
- `/coding-workflows:execute-issue-worktree` -- the command that creates worktrees this command cleans up
- `coding-workflows:issue-workflow` -- the skill defining execution phases, verification gates, and deferred work tracking
